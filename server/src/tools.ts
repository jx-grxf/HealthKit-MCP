/**
 * MCP tool definitions. All tools are read-only (`readOnlyHint: true`) and
 * scoped to the resolved user. Inputs are validated with zod; outputs are
 * returned both as JSON text and as `structuredContent` so agents can parse
 * them reliably.
 */

import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HealthStore, TrendMetric } from "./types.js";

const TREND_METRICS = [
  "steps",
  "activeEnergyKcal",
  "restingHeartRateBpm",
  "hrvSdnnMs",
  "sleepMinutes",
] as const;

interface Ctx {
  store: HealthStore;
  /** Resolves the user whose data a request may read. */
  resolveUserId: () => string;
}

function result(payload: unknown) {
  return {
    content: [{ type: "text" as const, text: JSON.stringify(payload, null, 2) }],
    structuredContent: payload as Record<string, unknown>,
  };
}

export function registerTools(server: McpServer, ctx: Ctx): void {
  server.registerTool(
    "get_daily_health_summary",
    {
      title: "Daily health summary",
      description:
        "Steps, active energy, resting heart rate, HRV and sleep for one day. " +
        "Omit `date` to get the most recent day available.",
      inputSchema: {
        date: z
          .string()
          .regex(/^\d{4}-\d{2}-\d{2}$/)
          .optional()
          .describe("ISO date (YYYY-MM-DD). Defaults to the latest available day."),
      },
      annotations: { readOnlyHint: true, openWorldHint: false },
    },
    async ({ date }) => {
      const day = await ctx.store.dailySummary(ctx.resolveUserId(), date);
      return result({ day });
    },
  );

  server.registerTool(
    "get_sleep_summary",
    {
      title: "Sleep summary",
      description:
        "Sleep stages (in-bed, asleep, REM, deep, core, awake) per night. " +
        "Pass `date` for one night, or `days` for the most recent N nights.",
      inputSchema: {
        date: z
          .string()
          .regex(/^\d{4}-\d{2}-\d{2}$/)
          .optional()
          .describe("Single night (YYYY-MM-DD)."),
        days: z
          .number()
          .int()
          .min(1)
          .max(90)
          .default(7)
          .describe("Number of recent nights when `date` is omitted."),
      },
      annotations: { readOnlyHint: true, openWorldHint: false },
    },
    async ({ date, days }) => {
      const nights = await ctx.store.sleep(ctx.resolveUserId(), { date, days });
      return result({ nights });
    },
  );

  server.registerTool(
    "list_recent_workouts",
    {
      title: "Recent workouts",
      description:
        "Most recent workouts with type, duration, distance, energy and average heart rate.",
      inputSchema: {
        limit: z.number().int().min(1).max(50).default(10),
        type: z
          .string()
          .optional()
          .describe('Filter by workout type, e.g. "running", "cycling", "strength".'),
      },
      annotations: { readOnlyHint: true, openWorldHint: false },
    },
    async ({ limit, type }) => {
      const workouts = await ctx.store.recentWorkouts(ctx.resolveUserId(), {
        limit,
        type,
      });
      return result({ workouts });
    },
  );

  server.registerTool(
    "get_training_load",
    {
      title: "Training load",
      description:
        "Acute (7-day) vs chronic (28-day) average daily active energy and their " +
        "ratio, plus workout count in the window. A ratio above ~1.5 suggests a load spike.",
      inputSchema: {
        windowDays: z.number().int().min(1).max(28).default(7),
      },
      annotations: { readOnlyHint: true, openWorldHint: false },
    },
    async ({ windowDays }) => {
      const load = await ctx.store.trainingLoad(ctx.resolveUserId(), windowDays);
      return result(load);
    },
  );

  server.registerTool(
    "get_health_trends",
    {
      title: "Health trends",
      description:
        "Daily time series for one metric over a window, for trend analysis.",
      inputSchema: {
        metric: z.enum(TREND_METRICS).describe("Which metric to trend."),
        windowDays: z.number().int().min(2).max(180).default(30),
      },
      annotations: { readOnlyHint: true, openWorldHint: false },
    },
    async ({ metric, windowDays }) => {
      const points = await ctx.store.trends(
        ctx.resolveUserId(),
        metric as TrendMetric,
        windowDays,
      );
      return result({ metric, windowDays, points });
    },
  );
}
