/**
 * Domain types for the health summaries the server serves.
 *
 * These mirror the Supabase schema in `supabase/migrations`. Everything is an
 * aggregate (per-day or per-workout) — never raw HealthKit samples — to keep
 * payloads small and the data minimised.
 */

export interface DailyHealth {
  date: string; // ISO date, YYYY-MM-DD
  steps: number | null;
  activeEnergyKcal: number | null;
  restingHeartRateBpm: number | null;
  hrvSdnnMs: number | null;
  sleepMinutes: number | null;
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

export type TrendMetric =
  | "steps"
  | "activeEnergyKcal"
  | "restingHeartRateBpm"
  | "hrvSdnnMs"
  | "sleepMinutes";

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
 * in-memory demo store. All methods are scoped to a single resolved user.
 */
export interface HealthStore {
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
    metric: TrendMetric,
    windowDays: number,
  ): Promise<TrendPoint[]>;
}
