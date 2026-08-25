/**
 * Domain types for the health summaries the server serves.
 *
 * These mirror the Supabase schema in `supabase/migrations`. Everything is an
 * aggregate (per-day, per-night or per-workout) — never raw HealthKit samples —
 * to keep payloads small and the data minimised.
 *
 * Metrics are open-ended by design. iOS 26 exposes 120 quantity types and 70
 * category types and the user decides which of them to share, so nothing here
 * hard-codes a metric list: a metric is identified by its `metricKey` and
 * described at runtime by `listMetrics`.
 */

/** How a day's samples are collapsed into a single value. */
export type Aggregation =
  | "sum"
  | "avg"
  | "latest"
  | "duration"
  | "count"
  | "max";

/** Reproductive-health, symptom and substance metrics are flagged so callers
 *  never bulk-enable them and consent screens can name them individually. */
export type Sensitivity = "standard" | "sensitive";

/** A metric the user has switched on. Metrics that are off are not described
 *  at all — the agent cannot learn they exist. */
export interface MetricInfo {
  metricKey: string;
  displayName: string;
  category: string;
  unit: string | null;
  aggregation: Aggregation;
  sensitivity: Sensitivity;
}

export interface MetricValue {
  metricKey: string;
  displayName: string;
  category: string;
  unit: string;
  /** Canonical value for the day, chosen by the metric's aggregation rule. */
  value: number | null;
  sampleCount: number;
}

export interface DailyHealth {
  date: string; // ISO date, YYYY-MM-DD
  metrics: MetricValue[];
}

export interface SleepNight {
  date: string; // night-of date (the morning you woke up)
  inBedMinutes: number | null;
  asleepMinutes: number | null;
  remMinutes: number | null;
  deepMinutes: number | null;
  coreMinutes: number | null;
  awakeMinutes: number | null;
}

export interface Workout {
  id: string;
  type: string; // e.g. "running", "cycling", "strength"
  start: string; // ISO timestamp
  end: string; // ISO timestamp
  durationSeconds: number;
  distanceMeters: number | null;
  activeEnergyKcal: number | null;
  averageHeartRateBpm: number | null;
  source: string | null;
}

export interface TrendPoint {
  date: string;
  value: number | null;
}

export interface TrainingLoad {
  windowDays: number;
  /** Acute (7-day) average daily active energy, kcal. */
  acuteKcalPerDay: number;
  /** Chronic (28-day) average daily active energy, kcal. */
  chronicKcalPerDay: number;
  /** Acute:chronic workload ratio. >1.5 is often flagged as a spike. */
  acuteChronicRatio: number | null;
  workoutCount: number;
}

/**
 * Read-only data source. Implemented by both the Supabase-backed store and the
 * in-memory demo store. Every method is scoped to a single resolved user and
 * must return only metrics that user has switched on.
 */
export interface HealthStore {
  /** Metrics this user shares. The catalogue of everything else stays hidden. */
  listMetrics(userId: string): Promise<MetricInfo[]>;
  dailySummary(userId: string, date?: string): Promise<DailyHealth | null>;
  sleep(
    userId: string,
    opts: { date?: string; days: number },
  ): Promise<SleepNight[]>;
  recentWorkouts(
    userId: string,
    opts: { limit: number; type?: string },
  ): Promise<Workout[]>;
  trainingLoad(userId: string, windowDays: number): Promise<TrainingLoad>;
  trends(
    userId: string,
    metricKey: string,
    windowDays: number,
  ): Promise<TrendPoint[]>;
}
