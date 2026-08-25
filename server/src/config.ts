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
  /** Port for the HTTP transport. */
  port: number;
  /** Canonical public URL of this MCP resource (the OAuth audience). */
  resourceUrl: string;
  /** Human-facing docs, advertised in the protected resource metadata. */
  documentationUrl: string;
  /** Override when the authorization server does not mint resource-bound audiences. */
  expectedAudience: string | undefined;
}

const DEMO_USER_ID = "demo-user";

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const supabaseUrl = clean(env.SUPABASE_URL);
  const supabaseServiceRoleKey = clean(env.SUPABASE_SERVICE_ROLE_KEY);
  const useSupabase = Boolean(supabaseUrl && supabaseServiceRoleKey);

  const transport = env.HEALTHKIT_MCP_TRANSPORT === "http" ? "http" : "stdio";

  // Under stdio there is no per-request identity, so a user id must be
  // configured. Under HTTP it comes from the OAuth token subject instead.
  const userId = clean(env.HEALTHKIT_MCP_USER_ID) ?? DEMO_USER_ID;
  if (transport === "stdio" && useSupabase && userId === DEMO_USER_ID) {
    throw new Error(
      "HEALTHKIT_MCP_USER_ID is required when Supabase is configured.",
    );
  }

  const resourceUrl =
    clean(env.MCP_RESOURCE_URL) ?? "http://localhost:8080/mcp";
  if (transport === "http" && !clean(env.MCP_RESOURCE_URL)) {
    // The resource URL is the OAuth audience. Guessing it would make tokens
    // minted for the real deployment fail to validate, or worse, make tokens
    // for something else validate here.
    throw new Error("MCP_RESOURCE_URL is required for the HTTP transport.");
  }

  return {
    supabaseUrl,
    supabaseServiceRoleKey,
    userId,
    transport,
    useSupabase,
    port: Number(clean(env.PORT) ?? 8080),
    resourceUrl,
    documentationUrl:
      clean(env.MCP_DOCUMENTATION_URL) ?? "https://wavelet.johannesgrof.me",
    expectedAudience: clean(env.MCP_EXPECTED_AUDIENCE),
  };
}

function clean(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}
