# Architecture

## The core constraint

Apple Health data lives on the device. There is **no server-side API**: no REST
endpoint, no OAuth flow, no token you can mint to pull a user's data. The only
way data leaves the phone is if an iOS app the user explicitly authorised reads
it via HealthKit and uploads it. Everything other wearable vendors do
server-side, we must do inside the iOS app. This makes the app the foundation,
not a thin client.

## Components

### 1. iOS app (`ios/`)

SwiftUI + HealthKit. Responsibilities:

- Request **read-only** HealthKit authorization for a minimal set of types:
  workouts, sleep, steps, active energy, resting heart rate, HRV.
- Incremental sync with `HKAnchoredObjectQuery` (persist the anchor per type) so
  each sync uploads only new samples.
- `HKObserverQuery` + `enableBackgroundDelivery` to be woken when new data
  lands. iOS treats the schedule as **advisory** — it defers for battery /
  connectivity / Low Power Mode — so the whole system is eventual-consistency,
  never real-time.
- **Aggregate on-device** into daily/nightly summaries before upload. Smaller
  payloads, less sensitive data, simpler backend.
- Authenticate the user (Sign in with Apple) and write to Supabase with the
  user's auth token, so Row-Level Security applies.

### 2. Backend (`supabase/`)

Supabase in an **EU region** (GDPR data residency). Postgres tables hold
aggregates only — never raw HealthKit samples:

- `health_days` — one row per user per day.
- `sleep_nights` — one row per user per night, with stages.
- `workouts` — one row per workout.
- `mcp_access_log` — every agent read, for auditability.

**Row-Level Security** on every table keys access to `auth.uid()`. The iOS app
authenticates as the user and can only touch its own rows. The MCP server uses
the service-role key (which bypasses RLS) and is therefore the trust boundary:
it must filter every query by the `user_id` it resolved from the request.

### 3. MCP server (`server/`)

A read-only Model Context Protocol server. Two data sources behind one
`HealthStore` interface:

- `DemoStore` — deterministic synthetic data, used whenever Supabase isn't
  configured. Makes the server runnable with zero setup.
- `SupabaseStore` — reads aggregates scoped to one user.

Two transports:

- **stdio** (implemented) — for Claude Code, Codex, Claude Desktop. No auth;
  the user is fixed by `HEALTHKIT_MCP_USER_ID`. This is the fast local wedge.
- **HTTP + OAuth 2.1** (next) — for ChatGPT Apps and Claude custom connectors.
  Requires public HTTPS, OAuth 2.1 (PKCE/S256), and RFC 9728 Protected Resource
  Metadata at `/.well-known/oauth-protected-resource`. The token subject
  replaces the env-configured user id.

## Identity & the auth boundary

In stdio/dev mode there is one user, set by config. In the remote build, the
agent (ChatGPT/Claude) performs OAuth against an authorization server; the MCP
server validates the token and uses its subject as the `user_id` for all
queries. The OAuth layer (DCR + PRM) is best delegated to a provider that
supports it (Stytch / WorkOS / Auth0 / Clerk) rather than hand-rolled — it is
the single most error-prone part of remote MCP.

## Data-flow summary

```
HealthKit sample → iOS aggregation → Supabase row (RLS, user-scoped)
                                          │
                          MCP tool call (read-only, audited)
                                          │
                                   agent reasoning
```

## Why aggregates, not raw

- **Privacy / GDPR**: health data is special-category; minimise what leaves the
  device and what an agent can ever see.
- **Apple Guideline 5.1.3**: HealthKit data must not be used for advertising or
  data-mining, and third-party (incl. AI) sharing must be disclosed and
  consented. Aggregates + explicit consent keep us inside the lines.
- **Practicality**: daily/nightly rollups are what an agent actually reasons
  over; raw sample streams would bloat payloads and context for no benefit.
