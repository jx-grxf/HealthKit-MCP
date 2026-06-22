/**
 * Runtime configuration, read once from the environment.
 *
 * The server has two data sources: a real Supabase backend and an in-memory
 * demo store. Demo mode is the default whenever Supabase is not fully
 * configured, so `npm run dev` always produces a working MCP server.
 */

export interface Config {
  supabaseUrl: string | undefined;
  supabaseServiceRoleKey: string | undefined;
  /** User whose data is served over stdio (no OAuth in dev mode). */
  userId: string;
  transport: "stdio" | "http";
  /** True when Supabase is fully configured; otherwise the demo store is used. */
  useSupabase: boolean;
}

const DEMO_USER_ID = "demo-user";

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const supabaseUrl = clean(env.SUPABASE_URL);
  const supabaseServiceRoleKey = clean(env.SUPABASE_SERVICE_ROLE_KEY);
  const useSupabase = Boolean(supabaseUrl && supabaseServiceRoleKey);

  const transport = env.HEALTHKIT_MCP_TRANSPORT === "http" ? "http" : "stdio";

  // Outside demo mode a user id is mandatory: without it the server would have
  // no one to scope rows to.
  const userId = clean(env.HEALTHKIT_MCP_USER_ID) ?? DEMO_USER_ID;
  if (useSupabase && userId === DEMO_USER_ID) {
    throw new Error(
      "HEALTHKIT_MCP_USER_ID is required when Supabase is configured.",
    );
  }

  return {
    supabaseUrl,
    supabaseServiceRoleKey,
    userId,
    transport,
    useSupabase,
  };
}

function clean(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}
