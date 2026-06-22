# HealthKit MCP server

Read-only Model Context Protocol server exposing Apple Health summaries.

## Run

```bash
npm install
npm run dev      # stdio, demo data (no backend needed)
```

Build and run the compiled server:

```bash
npm run build
npm start
```

## Configuration

See [`.env.example`](.env.example). With no Supabase vars set, the server runs
in **demo mode** (deterministic synthetic data). Set `SUPABASE_URL`,
`SUPABASE_SERVICE_ROLE_KEY` and `HEALTHKIT_MCP_USER_ID` to read real data.

| Var | Purpose |
|-----|---------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Server-side key (never ship in the app) |
| `HEALTHKIT_MCP_USER_ID` | User to scope to in stdio mode |
| `HEALTHKIT_MCP_TRANSPORT` | `stdio` (default) or `http` (not yet implemented) |

## Tools

All read-only (`readOnlyHint: true`):

- `get_daily_health_summary(date?)`
- `get_sleep_summary(date?, days=7)`
- `list_recent_workouts(limit=10, type?)`
- `get_training_load(windowDays=7)`
- `get_health_trends(metric, windowDays=30)`

## Layout

```
src/
  index.ts            entry; stdio transport, store selection
  config.ts           env → Config
  types.ts            domain types + HealthStore interface
  tools.ts            MCP tool definitions (zod inputs, read-only)
  stores/
    demoStore.ts      deterministic synthetic data
    supabaseStore.ts  user-scoped reads from Supabase
tests/
  demoStore.test.ts
```

## Scripts

`dev` · `build` · `start` · `test` · `typecheck` · `clean`
