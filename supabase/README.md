# Supabase backend

EU-region Postgres holding **aggregated** health data with Row-Level Security.

## Tables

| Table | Grain | Key |
|-------|-------|-----|
| `profiles` | one per user | `id` = `auth.users.id` |
| `health_days` | per user per day | `(user_id, date)` |
| `sleep_nights` | per user per night | `(user_id, date)` |
| `workouts` | per workout | `(user_id, id)` |
| `mcp_access_log` | per agent read | `id` |

RLS is enabled on all tables and keyed to `auth.uid()`. The iOS app
authenticates as the user (anon key) and can only touch its own rows. The MCP
server uses the **service-role** key — which bypasses RLS — so it must filter
every query by `user_id` itself.

## Apply the schema

Choose a project in an **EU region** when you create it (GDPR data residency).

With the Supabase CLI:

```bash
supabase link --project-ref <ref>
supabase db push        # applies migrations/0001_init.sql
```

Or paste [`migrations/0001_init.sql`](migrations/0001_init.sql) into the SQL
editor in the dashboard.

## Wire the MCP server to it

```bash
cd ../server
cp .env.example .env
# set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, HEALTHKIT_MCP_USER_ID
npm run dev
```

With those set the server reads real data instead of demo data.

## Keys

- **anon key** → iOS app only. Subject to RLS.
- **service-role key** → MCP server only, server-side. Never ship it in a client.
