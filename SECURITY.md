# Security Policy

## Supported Versions

HealthKit MCP is alpha software. Security fixes target the `main` branch.

## Reporting a Vulnerability

Please report security issues through GitHub Security Advisories:

https://github.com/jx-grxf/HealthKit-MCP/security/advisories/new

Include:

- affected component (iOS app, Supabase schema, MCP server) and version/commit
- reproduction steps
- expected impact
- whether health data, auth tokens, or service-role keys are involved

Do not open a public issue for a vulnerability before the maintainer has triaged it.

## Security Model

This project handles **special-category health data**. Core invariants:

- **Aggregates only.** Raw HealthKit samples never leave the device; the backend
  stores per-day / per-night / per-workout rollups.
- **User-scoped at every layer.** Row-Level Security keys all client access to
  `auth.uid()`. The MCP server uses the service-role key (which bypasses RLS) and
  must filter every query by the resolved `user_id` — that resolution is the
  trust boundary.
- **Read-only agents.** Every MCP tool is `readOnlyHint: true`; the server has no
  write path to health data.
- **Key separation.** The iOS app ships only the anon key. The service-role key
  is server-side only and must never appear in a client build or a commit.
- **Auditability.** Agent reads are recorded in `mcp_access_log`.
- **Remote auth.** The remote (HTTP) build authenticates agents with OAuth 2.1
  (PKCE/S256) and RFC 9728 Protected Resource Metadata — never API-key-only.

Do not commit `.env`, service-role keys, or any real user data.
