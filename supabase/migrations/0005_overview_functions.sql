-- Aggregate reads for agents.
--
-- An agent answering "how is my recovery?" previously had to call
-- get_health_trends once per metric — 133 round trips to see one picture. These
-- functions compute the summary in the database instead, so the same question
-- costs one call.
--
-- Both read `shared_metric_days`, never the base table, so the per-metric
-- consent join still decides what is visible. A metric the user has switched
-- off cannot appear in an overview any more than in a direct query.

-- What the user shares, and whether anything has actually arrived ------------
--
-- "Available" previously meant "authorised", which read as "there is data
-- here" for all 133 types even though two thirds were empty. Availability and
-- presence of data are different facts and are now reported separately.
create or replace function public.metric_availability(p_user_id uuid)
returns table (
  metric_key    text,
  display_name  text,
  category      text,
  unit          text,
  aggregation   text,
  sensitivity   text,
  has_data      boolean,
  first_date    date,
  last_date     date,
  day_count     integer
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    s.metric_key,
    s.display_name,
    s.category,
    s.canonical_unit,
    s.aggregation,
    s.sensitivity,
    count(d.date) > 0,
    min(d.date),
    max(d.date),
    count(d.date)::integer
  from public.shared_metrics s
  left join public.shared_metric_days d
    on d.user_id = s.user_id and d.metric_key = s.metric_key
  where s.user_id = p_user_id
  group by s.metric_key, s.display_name, s.category, s.canonical_unit,
           s.aggregation, s.sensitivity
  order by s.category, s.display_name;
$$;

-- One row per metric, summarising a window ----------------------------------
create or replace function public.metric_overview(p_user_id uuid, p_days integer default 30)
returns table (
  metric_key   text,
  display_name text,
  category     text,
  unit         text,
  latest_date  date,
  latest       double precision,
  average_7    double precision,
  average_30   double precision,
  minimum      double precision,
  maximum      double precision,
  day_count    integer
)
language sql
stable
security invoker
set search_path = public
as $$
  with window_days as (
    select *
    from public.shared_metric_days
    where user_id = p_user_id
      and date >= current_date - p_days
      and value is not null
  )
  select
    w.metric_key,
    max(w.display_name),
    max(w.category),
    max(w.unit),
    max(w.date),
    -- Value on the most recent day that has one.
    (array_agg(w.value order by w.date desc))[1],
    avg(w.value) filter (where w.date >= current_date - 7),
    avg(w.value) filter (where w.date >= current_date - 30),
    min(w.value),
    max(w.value),
    count(*)::integer
  from window_days w
  group by w.metric_key
  order by max(w.category), max(w.display_name);
$$;

comment on function public.metric_availability(uuid) is
  'Per-metric: shared with agents, and whether any data has actually arrived.';
comment on function public.metric_overview(uuid, integer) is
  'Per-metric window summary so an agent can see everything in one call.';
