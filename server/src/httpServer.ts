/**
 * Remote transport: Streamable HTTP + OAuth 2.1, for ChatGPT connectors and
 * Claude custom connectors.
 *
 * Runs stateless — a fresh MCP server and transport per request — because the
 * user identity comes from the bearer token on every call, so there is no
 * session state worth keeping and nothing to leak between users.
 */

import express, { type Request, type Response } from "express";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { requireBearerAuth } from "@modelcontextprotocol/sdk/server/auth/middleware/bearerAuth.js";
import { SupabaseTokenVerifier } from "./auth/supabaseVerifier.js";
import { registerTools } from "./tools.js";
import type { Config } from "./config.js";
import type { HealthStore } from "./types.js";

const SERVER_VERSION = "0.1.0";

export function createHttpApp(config: Config, store: HealthStore) {
  if (!config.supabaseUrl) {
    throw new Error("SUPABASE_URL is required for the HTTP transport.");
  }
  const resourceUrl = config.resourceUrl;
  const authorizationServer = `${config.supabaseUrl.replace(/\/+$/, "")}/auth/v1`;
  const metadataUrl = `${new URL(resourceUrl).origin}/.well-known/oauth-protected-resource`;

  const app = express();
  app.disable("x-powered-by");
  app.use(express.json({ limit: "1mb" }));

  // RFC 9728 Protected Resource Metadata. Clients fetch this after a 401 to
  // discover which authorization server to use, which is how ChatGPT and
  // Claude bootstrap the whole flow without being configured by hand.
  const metadata = {
    resource: resourceUrl,
    authorization_servers: [authorizationServer],
    bearer_methods_supported: ["header"],
    resource_documentation: config.documentationUrl,
  };
  const serveMetadata = (_req: Request, res: Response) => {
    res.set("Cache-Control", "public, max-age=3600").json(metadata);
  };
  // Both the bare and the path-suffixed form, since clients differ on which
  // they request for a resource that has a path.
  app.get("/.well-known/oauth-protected-resource", serveMetadata);
  app.get("/.well-known/oauth-protected-resource/*splat", serveMetadata);

  // Unauthenticated: no health data, nothing about the user.
  app.get("/healthz", (_req, res) => {
    res.json({ status: "ok", version: SERVER_VERSION });
  });

  const verifier = new SupabaseTokenVerifier({
    supabaseUrl: config.supabaseUrl,
    resourceUrl,
    expectedAudience: config.expectedAudience,
  });

  app.post(
    "/mcp",
    requireBearerAuth({ verifier, resourceMetadataUrl: metadataUrl }),
    async (req: Request, res: Response) => {
      // Set by requireBearerAuth; absent means the middleware did not run.
      const userId = req.auth?.extra?.userId;
      if (typeof userId !== "string") {
        res.status(401).json({ error: "unauthorized" });
        return;
      }

      const server = new McpServer({ name: "healthkit-mcp", version: SERVER_VERSION });
      registerTools(server, { store, resolveUserId: () => userId });

      const transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: undefined,
      });
      res.on("close", () => {
        void transport.close();
        void server.close();
      });

      await server.connect(transport);
      await transport.handleRequest(req, res, req.body);
    },
  );

  // GET/DELETE on /mcp are only meaningful for stateful sessions.
  app.all("/mcp", (_req, res) => {
    res.status(405).set("Allow", "POST").json({ error: "method_not_allowed" });
  });

  return app;
}
