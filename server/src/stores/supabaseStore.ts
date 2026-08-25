/**
 * Supabase-backed store.
 *
 * Reads aggregates written by the iOS app, scoped to a single user. It uses the
 * service-role key, which bypasses Row-Level Security — so this class is the
 * trust boundary and every query filters explicitly by `user_id`.
 *
 * It also reads *only* the `shared_*` views, never the underlying tables. Those
 * views inner-join `user_metric_settings`, so a metric the user has not
 * switched on cannot be returned even by a buggy query here. The consent
 * toggle is enforced by the database, not by this code.
 */

import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type {
  AccessEntry,
  Aggregation,
  DailyHealth,
  HealthOverview,
  MetricSummary,
  HealthStore,
  MetricInfo,
  MetricValue,
  Sensitivity,
  SleepNight,
  TrainingLoad,
  TrendPoint,
  Workout,
} from "../types.js";

/** Metric used for training load. Present in the catalog seed. */
const ENERGY_METRIC = "active_energy_burned";

export class SupabaseStore implements HealthStore {
  private readonly db: SupabaseClient;

  constructor(url: string, serviceRoleKey: string) {
    this.db = createClient(url, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
  }

  async listMetrics(userId: string): Promise<MetricInfo[]> {
    const { data, error } = await this.db.rpc("metric_availability", {
      p_user_id: userId,
    });
    if (error) throw error;
    return ((data ?? []) as Array<Record<string, unknown>>).map((r) => ({
      metricKey: String(r.metric_key),
      displayName: String(r.display_name),
      category: String(r.category),
      unit: (r.unit as string) ?? null,
      aggregation: r.aggregation as Aggregation,
      sensitivity: r.sensitivity as Sensitivity,
      hasData: Boolean(r.has_data),
      firstDate: (r.first_date as string) ?? null,
      lastDate: (r.last_date as string) ?? null,
      dayCount: Number(r.day_count ?? 0),
    }));
  }

  async logAccess(entry: AccessEntry): Promise<void> {
    // Deliberately swallows failures. The audit trail is for the user's benefit;
    // losing one line is far better than failing a read they asked for.
    try {
      await this.db.from("mcp_access_log").insert({
        user_id: entry.userId,
        tool: entry.tool,
        params: entry.params,
        client: entry.client,
      });
    } catch {
      // ignored on purpose
    }
  }

  async overview(userId: string, windowDays: number): Promise<HealthOverview> {
    const { data, error } = await this.db.rpc("metric_overview", {
      p_user_id: userId,
      p_days: windowDays,
    });
    if (error) throw error;

    const byCategory: Record<string, MetricSummary[]> = {};
    for (const r of (data ?? []) as Array<Record<string, unknown>>) {
      const category = String(r.category);
      (byCategory[category] ??= []).push({
        metricKey: String(r.metric_key),
        displayName: String(r.display_name),
        category,
        unit: String(r.unit),
        latestDate: (r.latest_date as string) ?? null,
        latest: num(r.latest),
        average7: round2opt(num(r.average_7)),
        average30: round2opt(num(r.average_30)),
        minimum: num(r.minimum),
        maximum: num(r.maximum),
        dayCount: Number(r.day_count ?? 0),
      });
    }

    // Fetched together so one question costs one round trip.
    const [sleep, recentWorkouts, trainingLoad] = await Promise.all([
      this.sleep(userId, { days: Math.min(windowDays, 90) }),
      this.recentWorkouts(userId, { limit: 20 }),
      this.trainingLoad(userId, 7),
    ]);

    return { windowDays, byCategory, sleep, recentWorkouts, trainingLoad };
  }

  async dailySummary(userId: string, date?: string): Promise<DailyHealth | null> {
    const day = date ?? (await this.latestDate(userId));
    if (!day) return null;

    const { data, error } = await this.db
      .from("shared_metric_days")
      .select("*")
      .eq("user_id", userId)
      .eq("date", day)
      .order("category", { ascending: true });
    if (error) throw error;
    if (!data || data.length === 0) return null;

    return { date: day, metrics: data.map(mapMetricValue) };
  }

  /** Most recent day this user has any shared data for. */
  private async latestDate(userId: string): Promise<string | null> {
    const { data, error } = await this.db
      .from("shared_metric_days")
      .select("date")
      .eq("user_id", userId)
      .order("date", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    return data ? String(data.date) : null;
  }

  async sleep(
    userId: string,
    opts: { date?: string; days: number },
  ): Promise<SleepNight[]> {
    let q = this.db
      .from("shared_sleep_nights")
      .select("*")
      .eq("user_id", userId)
      .order("date", { ascending: false });
    q = opts.date ? q.eq("date", opts.date) : q.limit(opts.days);
    const { data, error } = await q;
    if (error) throw error;
    return (data ?? []).map(mapSleep);
  }

  async recentWorkouts(
    userId: string,
    opts: { limit: number; type?: string },
  ): Promise<Workout[]> {
    let q = this.db
      .from("shared_workouts")
      .select("*")
      .eq("user_id", userId)
      .order("start_at", { ascending: false })
      .limit(opts.limit);
    if (opts.type) q = q.eq("type", opts.type);
    const { data, error } = await q;
    if (error) throw error;
    return (data ?? []).map(mapWorkout);
  }

  async trainingLoad(userId: string, windowDays: number): Promise<TrainingLoad> {
    const { data, error } = await this.db
      .from("shared_metric_days")
      .select("date, value")
      .eq("user_id", userId)
      .eq("metric_key", ENERGY_METRIC)
      .gte("date", isoDaysAgo(28))
      .order("date", { ascending: false });
    if (error) throw error;

    const rows = (data ?? []) as Array<{ date: string; value: number | null }>;
    const energySince = (cut: string) =>
      rows.filter((r) => r.date >= cut).map((r) => Number(r.value ?? 0));
    const acute = avg(energySince(isoDaysAgo(7)));
    const chronic = avg(energySince(isoDaysAgo(28)));

    const { count } = await this.db
      .from("shared_workouts")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .gte("start_at", `${isoDaysAgo(windowDays)}T00:00:00Z`);

    return {
      windowDays,
      acuteKcalPerDay: Math.round(acute),
      chronicKcalPerDay: Math.round(chronic),
      acuteChronicRatio: chronic > 0 ? round2(acute / chronic) : null,
      workoutCount: count ?? 0,
    };
  }

  async trends(
    userId: string,
    metricKeys: string[],
    windowDays: number,
  ): Promise<Record<string, TrendPoint[]>> {
    // One query for every requested metric rather than one per metric.
    const { data, error } = await this.db
      .from("shared_metric_days")
      .select("date, value, metric_key")
      .eq("user_id", userId)
      .in("metric_key", metricKeys)
      .gte("date", isoDaysAgo(windowDays))
      .order("date", { ascending: true });
    if (error) throw error;

    // Requested-but-absent metrics get an empty series, so the caller can tell
    // "nothing recorded" from "never asked for".
    const out: Record<string, TrendPoint[]> = {};
    for (const key of metricKeys) out[key] = [];
    for (const r of (data ?? []) as Array<Record<string, unknown>>) {
      const key = String(r.metric_key);
      (out[key] ??= []).push({ date: String(r.date), value: num(r.value) });
    }
    return out;
  }
}

function isoDaysAgo(n: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - n);
  return d.toISOString().slice(0, 10);
}

function avg(xs: number[]): number {
  return xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0;
}

/** Rounds a nullable average for display without inventing a value. */
function round2opt(n: number | null): number | null {
  return n === null ? null : Math.round(n * 100) / 100;
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

function num(v: unknown): number | null {
  return v === null || v === undefined ? null : Number(v);
}

function mapMetricValue(r: Record<string, unknown>): MetricValue {
  return {
    metricKey: String(r.metric_key),
    displayName: String(r.display_name),
    category: String(r.category),
    unit: String(r.unit),
    value: num(r.value),
    // null means unknown: HealthKit statistics do not report how many samples
    // they aggregated. Coercing that to 0 read as "no samples".
    sampleCount: r.sample_count == null ? null : Number(r.sample_count),
    sources: (r.sources as string[]) ?? null,
  };
}

function mapSleep(r: Record<string, unknown>): SleepNight {
  return {
    date: String(r.date),
    inBedMinutes: num(r.in_bed_minutes),
    asleepMinutes: num(r.asleep_minutes),
    remMinutes: num(r.rem_minutes),
    deepMinutes: num(r.deep_minutes),
    coreMinutes: num(r.core_minutes),
    awakeMinutes: num(r.awake_minutes),
  };
}

function mapWorkout(r: Record<string, unknown>): Workout {
  const start = String(r.start_at);
  const end = String(r.end_at);
  return {
    id: String(r.id),
    type: String(r.type),
    start,
    end,
    durationSeconds:
      num(r.duration_seconds) ??
      Math.max(0, Math.round((Date.parse(end) - Date.parse(start)) / 1000)),
    distanceMeters: num(r.distance_meters),
    activeEnergyKcal: num(r.active_energy_kcal),
    averageHeartRateBpm: num(r.avg_hr_bpm),
    source: (r.source as string) ?? null,
  };
}
