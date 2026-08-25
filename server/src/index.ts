#!/usr/bin/env node
/**
 * HealthKit MCP server entry point.
 *
 * Two transports:
 *   stdio — local agents (Claude Code, Codex, Claude Desktop). No auth; the
 *           user is fixed by configuration.
 *   http  — Streamable HTTP + OAuth 2.1 for ChatGPT and Claude connectors. The
 *           user is the token subject, resolved per request.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { loadConfig } from "./config.js";
import { DemoStore } from "./stores/demoStore.js";
import { SupabaseStore } from "./stores/supabaseStore.js";
import { createHttpApp } from "./httpServer.js";
import { registerTools } from "./tools.js";
import type { HealthStore } from "./types.js";

async function main(): Promise<void> {
  const config = loadConfig();

  const store: HealthStore =
    config.useSupabase
      ? new SupabaseStore(config.supabaseUrl!, config.supabaseServiceRoleKey!)
      : new DemoStore();

  if (config.transport === "http") {
    const app = createHttpApp(config, store);
    app.listen(config.port, () => {
      console.error(
        `healthkit-mcp listening on :${config.port} ` +
          `(source: ${config.useSupabase ? "supabase" : "demo"}, resource: ${config.resourceUrl})`,
      );
    });
    return;
  }

  const server = new McpServer({
    name: "healthkit-mcp",
    version: "0.1.0",
  });

  registerTools(server, {
    store,
    // stdio has no per-request identity, so the user is fixed by config. The
    // HTTP build will replace this with the OAuth token subject.
    resolveUserId: () => config.userId,
  });

  const transport = new StdioServerTransport();
  await server.connect(transport);

  // stderr is safe to log to under stdio (stdout carries the protocol).
  console.error(
    `healthkit-mcp ready (source: ${config.useSupabase ? "supabase" : "demo"}, user: ${config.userId})`,
  );
}

main().catch((err) => {
  console.error("healthkit-mcp failed to start:", err);
  process.exit(1);
});
