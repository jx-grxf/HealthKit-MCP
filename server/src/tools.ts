/**
 * MCP tool definitions. All tools are read-only (`readOnlyHint: true`) and
 * scoped to the resolved user. Inputs are validated with zod; outputs are
 * returned both as JSON text and as `structuredContent` so agents can parse
 * them reliably.
 */

import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HealthStore } from "./types.js";

interface Ctx {
  store: HealthStore;
  /** Resolves the user whose data a request may read. */
  resolveUserId: () => string;
  /** Identifies the calling agent, when the transport knows it. */
  clientId?: () => string | null;
}

/**
 * Runs a tool and records that it ran.
 *
 * Every read is auditable by the user: the point of the whole system is that
 * they can see what their assistants actually looked at, which requires the log
 * to be written on the read path rather than as an afterthought.
 */
async function audited<T>(
  ctx: Ctx,
  tool: string,
  params: Record<string, unknown>,
  run: (userId: string) => Promise<T>,
): Promise<T> {
  const userId = ctx.resolveUserId();
  const outcome = await run(userId);
  void ctx.store.logAccess({
    userId,
    tool,
    params,
    client: ctx.clientId?.() ?? null,
  });
  return outcome;
}

function result(payload: unknown) {
  return {
    content: [{ type: "text" as const, text: JSON.stringify(payload, null, 2) }],
    structuredContent: payload as Record<string, unknown>,
  };
}

export function registerTools(server: McpServer, ctx: Ctx): void {
  server.registerTool(
    "list_available_metrics",
    {
      title: "List available metrics",
      description:
        "Lists the health metrics this user shares, with units, aggregation, and " +
        "whether any data has actually arrived (`hasData`, `firstDate`, `lastDate`, " +
        "`dayCount`). Call this first. Sharing and having data are different: a metric " +
        "may be shared with `hasData: false` because nothing was ever recorded. Any " +
        "metric absent from this list is withheld by the user's consent settings, not " +
        "merely empty. Use the `metricKey` values with get_health_trends.",
      inputSchema: {},
      annotations: { readOnlyHint: true, openWorldHint: false },
    },
    async () => {
      const metrics = await audited(ctx, "list_available_metrics", {}, (u) =>
        ctx.store.listMetrics(u),
      );
      return result({
        metrics,
        count: metrics.length,
        withData: metrics.filter((m) => m.hasData).length,
      });
    },
  );

  server.registerTool(
    "get_health_overview",
    {
      title: "Health overview",
      description:
        "The whole picture in one call: every shared metric summarised over a window " +
        "(latest value, 7- and 30-day averages, min, max, days of data), grouped by " +
        "category, plus recent sleep, recent workouts and training load. Prefer this " +
        "over calling get_health_trends repeatedly — it is the right tool for broad " +
        "questions like overall fitness, recovery or how the last month went.",
      inputSchema: {
        windowDays: z.number().int().min(2).max(365).default(30),
      },
      annotations: { readOnlyHint: true, openWorldHint: false },
    },
    async ({ windowDays }) => {
      const overview = await audited(ctx, "get_health_overview", { windowDays }, (u) =>
        ctx.store.overview(u, windowDays),
      );
      return result(overview);
    },
  );

  server.registerTool(
    "get_daily_health_summary",
    {
      title: "Daily health summary",
      description:
        "Every metric the user shares, for one day, with its value and unit. " +
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
      const day = await audited(ctx, "get_daily_health_summary", { date }, (u) =>
        ctx.store.dailySummary(u, date),
      );
      return result({ day });
    },
  );

  server.registerTool(
    "get_sleep_summary",
    {
      title: "Sleep summary",
      description:
        "Sleep stages (in-bed, asleep, REM, deep, core, awake) per night, in minutes. " +
        "Pass `date` for one night, or `days` for the most recent N nights. Fields are " +
        "null when HealthKit has no samples of that stage — modern Apple Watch " +
        "recordings often omit in-bed entirely, so `inBedMinutes: null` is normal and " +
        "not an error. Short sessions (well under an hour) are naps rather than nights.",
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
      const nights = await audited(ctx, "get_sleep_summary", { date, days }, (u) =>
        ctx.store.sleep(u, { date, days }),
      );
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
      const workouts = await audited(ctx, "list_recent_workouts", { limit, type }, (u) =>
        ctx.store.recentWorkouts(u, { limit, type }),
      );
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
      const load = await audited(ctx, "get_training_load", { windowDays }, (u) =>
        ctx.store.trainingLoad(u, windowDays),
      );
      return result(load);
    },
  );

  server.registerTool(
    "get_health_trends",
    {
      title: "Health trends",
      description:
        "Daily time series for one or more metrics over a window. Pass several " +
        "metricKeys in one call rather than calling repeatedly. An unknown or " +
        "un-shared key returns an empty series for that key.",
      inputSchema: {
        metric: z
          .union([z.string().min(1), z.array(z.string().min(1)).min(1).max(40)])
          .describe(
            'One metricKey or an array of them, from list_available_metrics, e.g. "step_count".',
          ),
        windowDays: z.number().int().min(2).max(180).default(30),
      },
      annotations: { readOnlyHint: true, openWorldHint: false },
    },
    async ({ metric, windowDays }) => {
      const keys = Array.isArray(metric) ? metric : [metric];
      const series = await audited(ctx, "get_health_trends", { metric, windowDays }, (u) =>
        ctx.store.trends(u, keys, windowDays),
      );
      // A single-metric request keeps its original shape so existing callers
      // do not have to change.
      if (!Array.isArray(metric)) {
        return result({ metric, windowDays, points: series[metric] ?? [] });
      }
      return result({ windowDays, series });
    },
  );
}
