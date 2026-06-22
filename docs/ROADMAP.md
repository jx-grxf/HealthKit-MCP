# Roadmap

Build order is chosen so each phase produces something usable on its own, and
the hardest/riskiest work (the iOS app and OAuth) is de-risked early.

## Phase 0 — MCP server, demo mode ✅

- [x] Read-only MCP server with five tools over stdio.
- [x] Deterministic demo data store (zero-setup).
- [x] Supabase store + schema with RLS and audit log.
- [x] Tests + typecheck + CI.

You can wire this into Claude Code / Codex today and demo the whole tool surface.

## Phase 1 — iOS app → Supabase (the real pipe)

- [ ] SwiftUI app, Sign in with Apple, Supabase client.
- [ ] HealthKit read authorization for the minimal type set.
- [ ] Manual "Sync now": read today's aggregates for steps / energy / sleep,
      upsert to Supabase.
- [ ] Consent screen naming third-party agent sharing (Guideline 5.1.3).

**Done when:** real data from your phone appears in `health_days` and the MCP
server (Supabase mode) serves it to Claude Code.

## Phase 2 — Background incremental sync

- [ ] `HKAnchoredObjectQuery` with persisted anchors per type.
- [ ] `HKObserverQuery` + `enableBackgroundDelivery`.
- [ ] Sleep stage aggregation → `sleep_nights`; workouts → `workouts`.
- [ ] Backfill last 90 days on first run.

## Phase 3 — Remote MCP (HTTP + OAuth) for ChatGPT & Claude

- [ ] Streamable-HTTP transport.
- [ ] OAuth 2.1 (PKCE/S256) via a managed provider (Stytch / WorkOS / Auth0 / Clerk).
- [ ] RFC 9728 Protected Resource Metadata at
      `/.well-known/oauth-protected-resource`; 401 → `WWW-Authenticate`.
- [ ] Map token subject → `user_id`; write `mcp_access_log` on every call.
- [ ] Public HTTPS deploy.
- [ ] Wire into Claude (custom connector) and ChatGPT (Developer Mode app).

## Phase 4 — Hardening & launch

- [ ] Account + data deletion and export (GDPR).
- [ ] DPIA, privacy policy, consent records.
- [ ] App Store review (HealthKit usage strings, no medical claims).
- [ ] Claude connector directory submission (annotations, OAuth review).

## Explicit non-goals

- No raw HealthKit database upload.
- No "agent can see everything" blanket grant.
- No diagnosis / therapy claims.
- No API-key-only auth in production (OAuth 2.1 / OIDC only for the remote build).
- No use of health data for advertising, marketing, or data-mining.
