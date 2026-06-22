-- HealthKit MCP — initial schema.
--
-- Design rules:
--   * Store aggregates only (per-day, per-night, per-workout) — never raw
--     HealthKit samples. Data minimisation for GDPR special-category data.
--   * Row-Level Security on every table. A user can only ever touch their own
--     rows. The iOS app talks to the DB with the user's auth token; the MCP
--     server uses the service-role key and filters by user_id in code.
--   * Every MCP read is recorded in mcp_access_log for auditability.

-- Profiles ------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  region      text,
  created_at  timestamptz not null default now(),
  -- Explicit consent capture for sharing with third-party agents.
  agent_sharing_consent_at timestamptz
);

-- Daily aggregates ----------------------------------------------------------
create table if not exists public.health_days (
  user_id            uuid not null references auth.users (id) on delete cascade,
  date               date not null,
  steps              integer,
  active_energy_kcal integer,
  resting_hr_bpm     integer,
  hrv_sdnn_ms        integer,
  sleep_minutes      integer,
  updated_at         timestamptz not null default now(),
  primary key (user_id, date)
);

-- Sleep nights --------------------------------------------------------------
create table if not exists public.sleep_nights (
  user_id        uuid not null references auth.users (id) on delete cascade,
  date           date not null,
  in_bed_minutes integer,
  asleep_minutes integer,
  rem_minutes    integer,
  deep_minutes   integer,
  core_minutes   integer,
  awake_minutes  integer,
  updated_at     timestamptz not null default now(),
  primary key (user_id, date)
);

-- Workouts ------------------------------------------------------------------
create table if not exists public.workouts (
  id                 text not null,
  user_id            uuid not null references auth.users (id) on delete cascade,
  type               text not null,
  start_at           timestamptz not null,
  end_at             timestamptz not null,
  duration_seconds   integer,
  distance_meters    integer,
  active_energy_kcal integer,
  avg_hr_bpm         integer,
  source             text,
  updated_at         timestamptz not null default now(),
  primary key (user_id, id)
);

create index if not exists workouts_user_start_idx
  on public.workouts (user_id, start_at desc);

-- Audit log of agent reads --------------------------------------------------
create table if not exists public.mcp_access_log (
  id        bigint generated always as identity primary key,
  user_id   uuid not null references auth.users (id) on delete cascade,
  tool      text not null,
  params    jsonb,
  client    text,
  at        timestamptz not null default now()
);

create index if not exists mcp_access_log_user_at_idx
  on public.mcp_access_log (user_id, at desc);

-- Row-Level Security --------------------------------------------------------
alter table public.profiles       enable row level security;
alter table public.health_days    enable row level security;
alter table public.sleep_nights   enable row level security;
alter table public.workouts       enable row level security;
alter table public.mcp_access_log enable row level security;

-- The service-role key used by the MCP server bypasses RLS; these policies
-- govern the iOS app, which authenticates as the end user.
create policy "own profile" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "own health_days" on public.health_days
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own sleep_nights" on public.sleep_nights
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own workouts" on public.workouts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Users may read their own audit log but never write it (server-only writes).
create policy "read own access log" on public.mcp_access_log
  for select using (auth.uid() = user_id);
