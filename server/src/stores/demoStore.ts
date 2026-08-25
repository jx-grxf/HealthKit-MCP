/**
 * In-memory demo store with deterministic synthetic data.
 *
 * Lets the MCP server run with zero backend so it can be wired into Claude
 * Code / Codex / ChatGPT immediately. Values are derived from the date and
 * metric key, so the same input always yields the same output (stable across
 * restarts and easy to assert in tests).
 *
 * The demo user has a fixed set of metrics "switched on". Anything outside that
 * set behaves exactly as it would in production for a metric the user has not
 * consented to: absent, not empty.
 */

import type {
  DailyHealth,
  HealthStore,
  MetricInfo,
  MetricValue,
  SleepNight,
  TrainingLoad,
  TrendPoint,
  Workout,
} from "../types.js";

const WORKOUT_TYPES = ["running", "cycling", "strength", "walking"] as const;

/** What the demo user shares, plus the range each value is generated in. */
interface DemoMetric extends MetricInfo {
  min: number;
  max: number;
}

const DEMO_METRICS: DemoMetric[] = [
  { metricKey: "step_count", displayName: "Steps", category: "activity", unit: "count", aggregation: "sum", sensitivity: "standard", min: 4000, max: 13000 },
  { metricKey: "active_energy_burned", displayName: "Active Energy", category: "activity", unit: "kcal", aggregation: "sum", sensitivity: "standard", min: 300, max: 1000 },
  { metricKey: "apple_exercise_time", displayName: "Exercise Minutes", category: "activity", unit: "min", aggregation: "sum", sensitivity: "standard", min: 10, max: 95 },
  { metricKey: "flights_climbed", displayName: "Flights Climbed", category: "activity", unit: "count", aggregation: "sum", sensitivity: "standard", min: 2, max: 28 },
  { metricKey: "resting_heart_rate", displayName: "Resting Heart Rate", category: "heart", unit: "count/min", aggregation: "avg", sensitivity: "standard", min: 52, max: 66 },
  { metricKey: "heart_rate_variability_sdnn", displayName: "Heart Rate Variability (SDNN)", category: "heart", unit: "ms", aggregation: "avg", sensitivity: "standard", min: 35, max: 95 },
  { metricKey: "respiratory_rate", displayName: "Respiratory Rate", category: "respiratory", unit: "count/min", aggregation: "avg", sensitivity: "standard", min: 12, max: 18 },
  { metricKey: "oxygen_saturation", displayName: "Blood Oxygen", category: "vitals", unit: "percent", aggregation: "avg", sensitivity: "standard", min: 94, max: 99 },
  { metricKey: "body_mass", displayName: "Body Mass", category: "body", unit: "kg", aggregation: "avg", sensitivity: "standard", min: 72, max: 76 },
  { metricKey: "sleep_analysis", displayName: "Sleep Analysis", category: "sleep", unit: "min", aggregation: "duration", sensitivity: "standard", min: 360, max: 510 },
];

const BY_KEY = new Map(DEMO_METRICS.map((m) => [m.metricKey, m]));

/** Tiny deterministic hash → [0, 1). No Math.random, so results are stable. */
function seed(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return ((h >>> 0) % 100000) / 100000;
}

function ymd(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/** Days ago relative to a fixed reference so output is reproducible. */
function dateNDaysAgo(reference: Date, n: number): Date {
  const d = new Date(reference);
  d.setUTCDate(d.getUTCDate() - n);
  return d;
}

function valueFor(metric: DemoMetric, date: string): number {
  const r = seed(`${date}:${metric.metricKey}`);
  return Math.round(metric.min + r * (metric.max - metric.min));
}

function metricValueFor(metric: DemoMetric, date: string): MetricValue {
  return {
    metricKey: metric.metricKey,
    displayName: metric.displayName,
    category: metric.category,
    unit: metric.unit ?? "count",
    value: valueFor(metric, date),
    sampleCount: 1 + Math.round(seed(`${date}:${metric.metricKey}:n`) * 20),
  };
}

function sleepFor(date: string): SleepNight {
  const asleep = valueFor(BY_KEY.get("sleep_analysis")!, date);
  const r = seed(date + "s");
  const deep = Math.round(asleep * (0.13 + r * 0.07));
  const rem = Math.round(asleep * (0.18 + r * 0.07));
  const core = asleep - deep - rem;
  return {
    date,
    inBedMinutes: asleep + Math.round(20 + r * 40),
    asleepMinutes: asleep,
    remMinutes: rem,
    deepMinutes: deep,
    coreMinutes: core,
    awakeMinutes: Math.round(10 + r * 30),
  };
}

export class DemoStore implements HealthStore {
  /** Reference "today". Fixed at construction so a session is internally consistent. */
  private readonly reference: Date;

  constructor(reference: Date = new Date()) {
    // Normalise to midnight UTC.
    this.reference = new Date(`${ymd(reference)}T00:00:00.000Z`);
  }

  private latestDate(): string {
    // Demo data lags one day, mirroring HealthKit's eventual-consistency sync.
    return ymd(dateNDaysAgo(this.reference, 1));
  }

  async listMetrics(_userId: string): Promise<MetricInfo[]> {
    return DEMO_METRICS.map(({ min: _min, max: _max, ...info }) => info);
  }

  async dailySummary(_userId: string, date?: string): Promise<DailyHealth> {
    const day = date ?? this.latestDate();
    return {
      date: day,
      metrics: DEMO_METRICS.map((m) => metricValueFor(m, day)),
    };
  }

  async sleep(
    _userId: string,
    opts: { date?: string; days: number },
  ): Promise<SleepNight[]> {
    if (opts.date) return [sleepFor(opts.date)];
    const out: SleepNight[] = [];
    for (let i = 1; i <= opts.days; i++) {
      out.push(sleepFor(ymd(dateNDaysAgo(this.reference, i))));
    }
    return out;
  }

  async recentWorkouts(
    _userId: string,
    opts: { limit: number; type?: string },
  ): Promise<Workout[]> {
    const out: Workout[] = [];
    let i = 1;
    while (out.length < opts.limit && i < 90) {
      const date = ymd(dateNDaysAgo(this.reference, i));
      const r = seed(date + "w");
      i++;
      // ~60% of days have a workout.
      if (r < 0.4) continue;
      const type = WORKOUT_TYPES[Math.floor(r * WORKOUT_TYPES.length)]!;
      if (opts.type && type !== opts.type) continue;
      const durationSeconds = Math.round(1500 + r * 4500);
      const start = new Date(`${date}T17:30:00.000Z`);
      const end = new Date(start.getTime() + durationSeconds * 1000);
      const hasDistance =
        type === "running" || type === "cycling" || type === "walking";
      out.push({
        id: `demo-${date}`,
        type,
        start: start.toISOString(),
        end: end.toISOString(),
        durationSeconds,
        distanceMeters: hasDistance ? Math.round(3000 + r * 12000) : null,
        activeEnergyKcal: Math.round(200 + r * 600),
        averageHeartRateBpm: Math.round(120 + r * 40),
        source: "Demo",
      });
    }
    return out;
  }

  async trainingLoad(userId: string, windowDays: number): Promise<TrainingLoad> {
    const energy = BY_KEY.get("active_energy_burned")!;
    const daily: number[] = [];
    for (let i = 1; i <= 28; i++) {
      daily.push(valueFor(energy, ymd(dateNDaysAgo(this.reference, i))));
    }
    const acute = avg(daily.slice(0, 7));
    const chronic = avg(daily.slice(0, 28));
    const workouts = await this.recentWorkouts(userId, { limit: 100 });
    return {
      windowDays,
      acuteKcalPerDay: Math.round(acute),
      chronicKcalPerDay: Math.round(chronic),
      acuteChronicRatio: chronic > 0 ? round2(acute / chronic) : null,
      workoutCount: workouts.filter(
        (w) =>
          new Date(w.start).getTime() >=
          dateNDaysAgo(this.reference, windowDays).getTime(),
      ).length,
    };
  }

  async trends(
    _userId: string,
    metricKey: string,
    windowDays: number,
  ): Promise<TrendPoint[]> {
    const metric = BY_KEY.get(metricKey);
    // Unknown or un-shared metric: no series, mirroring production behaviour
    // where the consent join simply returns nothing.
    if (!metric) return [];
    const out: TrendPoint[] = [];
    for (let i = windowDays; i >= 1; i--) {
      const date = ymd(dateNDaysAgo(this.reference, i));
      out.push({ date, value: valueFor(metric, date) });
    }
    return out;
  }
}

function avg(xs: number[]): number {
  return xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0;
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}
