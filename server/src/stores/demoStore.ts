/**
 * In-memory demo store with deterministic synthetic data.
 *
 * Lets the MCP server run with zero backend so it can be wired into Claude
 * Code / Codex / ChatGPT immediately. Data is generated from the date string,
 * so the same date always yields the same values (stable across restarts and
 * easy to assert in tests).
 */

import type {
  DailyHealth,
  HealthStore,
  SleepNight,
  TrainingLoad,
  TrendMetric,
  TrendPoint,
  Workout,
} from "../types.js";

const WORKOUT_TYPES = ["running", "cycling", "strength", "walking"] as const;

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

function dayFor(date: string): DailyHealth {
  const r = seed(date);
  const r2 = seed(date + "x");
  return {
    date,
    steps: Math.round(4000 + r * 9000),
    activeEnergyKcal: Math.round(300 + r2 * 700),
    restingHeartRateBpm: Math.round(52 + r * 14),
    hrvSdnnMs: Math.round(35 + r2 * 60),
    sleepMinutes: Math.round(360 + r * 150),
  };
}

function sleepFor(date: string): SleepNight {
  const day = dayFor(date);
  const asleep = day.sleepMinutes ?? 420;
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

  async dailySummary(_userId: string, date?: string): Promise<DailyHealth> {
    return dayFor(date ?? this.latestDate());
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
      const hasDistance = type === "running" || type === "cycling" || type === "walking";
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

  async trainingLoad(_userId: string, windowDays: number): Promise<TrainingLoad> {
    const days: DailyHealth[] = [];
    for (let i = 1; i <= 28; i++) {
      days.push(dayFor(ymd(dateNDaysAgo(this.reference, i))));
    }
    const avg = (xs: number[]) =>
      xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0;
    const energy = (slice: DailyHealth[]) =>
      slice.map((d) => d.activeEnergyKcal ?? 0);
    const acute = avg(energy(days.slice(0, 7)));
    const chronic = avg(energy(days.slice(0, 28)));
    const workouts = await this.recentWorkouts(_userId, { limit: 100 });
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
    metric: TrendMetric,
    windowDays: number,
  ): Promise<TrendPoint[]> {
    const out: TrendPoint[] = [];
    for (let i = windowDays; i >= 1; i--) {
      const date = ymd(dateNDaysAgo(this.reference, i));
      out.push({ date, value: dayFor(date)[metric] });
    }
    return out;
  }
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}
