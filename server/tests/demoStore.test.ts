import { describe, expect, it } from "vitest";
import { DemoStore } from "../src/stores/demoStore.js";

const REF = new Date("2026-06-20T00:00:00.000Z");

function valueOf(
  day: { metrics: Array<{ metricKey: string; value: number | null }> },
  key: string,
): number | null {
  return day.metrics.find((m) => m.metricKey === key)?.value ?? null;
}

describe("DemoStore", () => {
  it("lists the metrics the demo user shares, with units and aggregation", async () => {
    const metrics = await new DemoStore(REF).listMetrics("u");
    expect(metrics.length).toBeGreaterThan(0);
    const steps = metrics.find((m) => m.metricKey === "step_count");
    expect(steps).toMatchObject({
      displayName: "Steps",
      category: "activity",
      unit: "count",
      aggregation: "sum",
      sensitivity: "standard",
    });
  });

  it("never exposes a metric the user has not switched on", async () => {
    const store = new DemoStore(REF);
    const shared = new Set(
      (await store.listMetrics("u")).map((m) => m.metricKey),
    );
    // Reproductive-health data exists in the catalog but is not shared here.
    expect(shared.has("sexual_activity")).toBe(false);

    const day = await store.dailySummary("u", "2026-06-10");
    expect(day.metrics.every((m) => shared.has(m.metricKey))).toBe(true);
    expect((await store.trends("u", ["sexual_activity"], 14)).sexual_activity).toEqual([]);
  });

  it("returns a deterministic daily summary for a given date", async () => {
    const a = await new DemoStore(REF).dailySummary("u", "2026-06-10");
    const b = await new DemoStore(REF).dailySummary("u", "2026-06-10");
    expect(a).toEqual(b);
    expect(a.date).toBe("2026-06-10");
    expect(valueOf(a, "step_count")!).toBeGreaterThan(0);
    expect(valueOf(a, "resting_heart_rate")!).toBeGreaterThan(40);
  });

  it("defaults to the latest available day (yesterday)", async () => {
    const day = await new DemoStore(REF).dailySummary("u");
    expect(day.date).toBe("2026-06-19");
  });

  it("returns N recent sleep nights", async () => {
    const nights = await new DemoStore(REF).sleep("u", { days: 5 });
    expect(nights).toHaveLength(5);
    for (const n of nights) {
      expect(n.asleepMinutes ?? 0).toBeGreaterThan(0);
      expect(n.inBedMinutes ?? 0).toBeGreaterThanOrEqual(n.asleepMinutes ?? 0);
    }
  });

  it("respects the workout limit and type filter", async () => {
    const store = new DemoStore(REF);
    const workouts = await store.recentWorkouts("u", { limit: 3 });
    expect(workouts.length).toBeLessThanOrEqual(3);

    const runs = await store.recentWorkouts("u", { limit: 10, type: "running" });
    for (const w of runs) expect(w.type).toBe("running");
  });

  it("computes an acute:chronic ratio", async () => {
    const load = await new DemoStore(REF).trainingLoad("u", 7);
    expect(load.acuteKcalPerDay).toBeGreaterThan(0);
    expect(load.chronicKcalPerDay).toBeGreaterThan(0);
    expect(load.acuteChronicRatio).toBeGreaterThan(0);
  });

  it("returns an ascending trend series of the requested length", async () => {
    const series = await new DemoStore(REF).trends("u", ["step_count"], 14);
    const points = series.step_count!;
    expect(points).toHaveLength(14);
    expect(points[0]!.date < points[points.length - 1]!.date).toBe(true);
  });

  it("returns several metrics from a single trends call", async () => {
    const series = await new DemoStore(REF).trends(
      "u",
      ["step_count", "resting_heart_rate", "not_a_metric"],
      7,
    );
    expect(Object.keys(series).sort()).toEqual([
      "not_a_metric",
      "resting_heart_rate",
      "step_count",
    ]);
    expect(series.step_count).toHaveLength(7);
    // Requested but unknown: an empty series, not a missing key, so the caller
    // can tell "nothing recorded" from "never asked for".
    expect(series.not_a_metric).toEqual([]);
  });

  it("reports whether a shared metric actually has data", async () => {
    const metrics = await new DemoStore(REF).listMetrics("u");
    for (const metric of metrics) {
      expect(metric).toHaveProperty("hasData");
      expect(metric.lastDate).toBe("2026-06-19");
    }
  });

  it("summarises every category in one overview call", async () => {
    const overview = await new DemoStore(REF).overview("u", 30);
    expect(overview.windowDays).toBe(30);
    expect(Object.keys(overview.byCategory)).toContain("activity");
    const activity = overview.byCategory.activity!;
    const steps = activity.find((m) => m.metricKey === "step_count")!;
    expect(steps.average7).toBeGreaterThan(0);
    expect(steps.minimum).toBeLessThanOrEqual(steps.maximum!);
    expect(overview.sleep.length).toBeGreaterThan(0);
    expect(overview.trainingLoad.acuteKcalPerDay).toBeGreaterThan(0);
  });
});
