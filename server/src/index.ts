#!/usr/bin/env node
/**
 * HealthKit MCP server entry point.
 *
 * Default transport is stdio, for local agents (Claude Code, Codex, Claude
 * Desktop). The remote HTTP transport — with OAuth 2.1 + RFC 9728 for ChatGPT
 * and Claude custom connectors — is tracked in docs/ROADMAP.md and not yet
 * wired here.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { loadConfig } from "./config.js";
import { DemoStore } from "./stores/demoStore.js";
import { SupabaseStore } from "./stores/supabaseStore.js";
import { registerTools } from "./tools.js";
import type { HealthStore } from "./types.js";

async function main(): Promise<void> {
  const config = loadConfig();

  const store: HealthStore =
    config.useSupabase
      ? new SupabaseStore(config.supabaseUrl!, config.supabaseServiceRoleKey!)
      : new DemoStore();

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

  if (config.transport !== "stdio") {
    throw new Error(
      `Transport "${config.transport}" is not implemented yet. Use stdio. ` +
        "See docs/ROADMAP.md for the remote HTTP + OAuth plan.",
    );
  }

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
