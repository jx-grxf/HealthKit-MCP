/**
 * Supabase-backed store. Reads daily aggregates and workouts written by the
 * iOS app, scoped to a single user. Uses the service-role key, so every query
 * filters explicitly by `user_id` — the server is the trust boundary that maps
 * an authenticated identity to its own rows.
 */

import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type {
  DailyHealth,
  HealthStore,
  SleepNight,
  TrainingLoad,
  TrendMetric,
  TrendPoint,
  Workout,
} from "../types.js";

const METRIC_COLUMNS: Record<TrendMetric, string> = {
  steps: "steps",
  activeEnergyKcal: "active_energy_kcal",
  restingHeartRateBpm: "resting_hr_bpm",
  hrvSdnnMs: "hrv_sdnn_ms",
  sleepMinutes: "sleep_minutes",
};

export class SupabaseStore implements HealthStore {
  private readonly db: SupabaseClient;

  constructor(url: string, serviceRoleKey: string) {
    this.db = createClient(url, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
  }

  async dailySummary(userId: string, date?: string): Promise<DailyHealth | null> {
    let q = this.db
      .from("health_days")
      .select("*")
      .eq("user_id", userId)
      .order("date", { ascending: false })
      .limit(1);
    if (date) q = q.eq("date", date);
    const { data, error } = await q.maybeSingle();
    if (error) throw error;
    return data ? mapDay(data) : null;
  }

  async sleep(
    userId: string,
    opts: { date?: string; days: number },
  ): Promise<SleepNight[]> {
    let q = this.db
      .from("sleep_nights")
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
      .from("workouts")
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
    const since = isoDaysAgo(28);
    const { data, error } = await this.db
      .from("health_days")
      .select("date, active_energy_kcal")
      .eq("user_id", userId)
      .gte("date", since)
      .order("date", { ascending: false });
    if (error) throw error;
    const rows = data ?? [];
    const energy = (cut: string) =>
      rows
        .filter((r) => r.date >= cut)
        .map((r) => Number(r.active_energy_kcal ?? 0));
    const avg = (xs: number[]) =>
      xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0;
    const acute = avg(energy(isoDaysAgo(7)));
    const chronic = avg(energy(isoDaysAgo(28)));

    const { count } = await this.db
      .from("workouts")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .gte("start_at", `${isoDaysAgo(windowDays)}T00:00:00Z`);

    return {
      windowDays,
      acuteKcalPerDay: Math.round(acute),
      chronicKcalPerDay: Math.round(chronic),
      acuteChronicRatio:
        chronic > 0 ? Math.round((acute / chronic) * 100) / 100 : null,
      workoutCount: count ?? 0,
    };
  }

  async trends(
    userId: string,
    metric: TrendMetric,
    windowDays: number,
  ): Promise<TrendPoint[]> {
    const column = METRIC_COLUMNS[metric];
    // The column is chosen at runtime, which supabase-js's typed `select()`
    // can't model, so select the row and pick the column ourselves.
    const { data, error } = await this.db
      .from("health_days")
      .select("*")
      .eq("user_id", userId)
      .gte("date", isoDaysAgo(windowDays))
      .order("date", { ascending: true });
    if (error) throw error;
    return ((data ?? []) as Array<Record<string, unknown>>).map((r) => ({
      date: String(r.date),
      value: num(r[column]),
    }));
  }
}

function isoDaysAgo(n: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - n);
  return d.toISOString().slice(0, 10);
}

function num(v: unknown): number | null {
  return v === null || v === undefined ? null : Number(v);
}

function mapDay(r: Record<string, unknown>): DailyHealth {
  return {
    date: String(r.date),
    steps: num(r.steps),
    activeEnergyKcal: num(r.active_energy_kcal),
    restingHeartRateBpm: num(r.resting_hr_bpm),
    hrvSdnnMs: num(r.hrv_sdnn_ms),
    sleepMinutes: num(r.sleep_minutes),
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
