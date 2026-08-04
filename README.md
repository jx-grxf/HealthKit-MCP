<div align="center">

# HealthKit MCP

**Give agents read-only access to your Apple Health data — sleep, workouts, training load and trends — over the Model Context Protocol.**

![Status](https://img.shields.io/badge/status-alpha-0ea5e9)
![TypeScript](https://img.shields.io/badge/TypeScript-5.7-3178C6?logo=typescript&logoColor=white)
![Node](https://img.shields.io/badge/Node.js-22%2B-339933?logo=node.js&logoColor=white)
![MCP](https://img.shields.io/badge/protocol-MCP-111827)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

<p><strong>iPhone reads HealthKit → encrypted summaries in Supabase → read-only MCP server → ChatGPT · Claude · Codex · Claude Code.</strong></p>

</div>

---

<!-- DEMO: add a screen recording here — screen recording of an agent answering a question from your Health data
     Record with ⌘⇧5, then: jx-grxf/tools/make-demo.sh <recording.mov> .
<p align="center"><img src=".github/assets/demo.gif" alt="" width="720"></p>
-->

## Why

Apple Health is the richest personal-health dataset most people own, but it is locked on-device: there is no REST endpoint, no OAuth, no server-side token. The only way out is an iOS app that the user explicitly authorises. HealthKit MCP is that bridge — a small iPhone app that syncs **aggregates** (not raw samples) to an EU-region backend, and a read-only MCP server that lets any MCP-capable agent reason over them.

In regions where ChatGPT Health isn't available, and for agents (Claude, Codex, Claude Code) that have no health integration at all, this is the missing connector.

## Architecture

```
┌─────────────┐  HKAnchoredObjectQuery + HKObserverQuery
│  iOS app    │  + background delivery (hourly/daily)
│ SwiftUI +   │──────────────┐  push deltas only, aggregates first
│ HealthKit   │  Sign in w/  │
└─────────────┘  Apple       ▼
                       ┌───────────────────────┐
                       │ Supabase (EU region)   │  Postgres + RLS per user
                       │ Auth · DB · Storage    │  daily/nightly aggregates
                       └──────────┬────────────┘
                                  │ service-role read, scoped by user_id
                       ┌──────────▼────────────┐
                       │ MCP server (this repo) │  read-only tools
                       │ stdio now · HTTP+OAuth │  RFC 9728 + OAuth 2.1 (next)
                       └──────────┬────────────┘
              ┌───────────────────┼────────────────────┐
          ChatGPT (Apps)     Claude (connector)    Codex / Claude Code
```

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full design and [`docs/ROADMAP.md`](docs/ROADMAP.md) for the phased build.

## Repository layout

| Path | What |
|------|------|
| [`server/`](server/) | TypeScript MCP server. Runs in **demo mode** out of the box; switches to Supabase when configured. |
| [`supabase/`](supabase/) | Postgres schema with Row-Level Security and an agent-read audit log. |
| [`ios/`](ios/) | SwiftUI + HealthKit app spec — the sync client (the hard, non-optional core). |
| [`docs/`](docs/) | Roadmap, compliance notes, integration guides. |

## Quick start (server, demo mode)

No backend, no Apple account — runnable in a minute.

```bash
cd server
npm install
npm run dev      # stdio MCP server with synthetic data
```

Wire it into **Claude Code**:

```bash
claude mcp add healthkit -- npx -y tsx /absolute/path/to/server/src/index.ts
```

Or drop this into a project `.mcp.json` (Claude Code / Codex):

```json
{
  "mcpServers": {
    "healthkit": {
      "command": "node",
      "args": ["/absolute/path/to/server/dist/index.js"]
    }
  }
}
```

Then ask your agent: *"What was my training load this week?"* — it will call `get_training_load`.

## Tools (all read-only)

| Tool | Returns |
|------|---------|
| `get_daily_health_summary` | Steps, active energy, resting HR, HRV, sleep for a day |
| `get_sleep_summary` | Sleep stages per night (in-bed, asleep, REM, deep, core, awake) |
| `list_recent_workouts` | Recent workouts with duration, distance, energy, avg HR |
| `get_training_load` | Acute vs chronic load and acute:chronic ratio |
| `get_health_trends` | Daily time series for a single metric |

All tools carry `readOnlyHint: true`. The server never writes health data.

## Status

Alpha. The MCP server and Supabase schema are functional; the iOS app and the remote HTTP + OAuth transport are next. See [`docs/ROADMAP.md`](docs/ROADMAP.md).

## License

MIT © 2026 Johannes Grof
