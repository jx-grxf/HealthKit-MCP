-- Correct two things the first agent review exposed.
--
-- 1. Percent metrics were labelled "percent" while carrying HealthKit's raw
--    0–1 ratio, so blood oxygen read as 0.97 "percent" and walking double
--    support as 0.27 "percent" — both off by a factor of one hundred. The unit
--    is now "%" and the app scales the value, so 97 % means 97 %.
--
-- 2. sample_count was written as 1 for every statistics-derived row, which
--    claimed a single reading stood behind a whole day of heart rate. HealthKit
--    statistics do not expose the underlying sample count, so it becomes null:
--    unknown, rather than a confident lie.

update public.metric_catalog
   set canonical_unit = '%'
 where canonical_unit = 'percent';

alter table public.health_metric_days
  alter column sample_count drop not null,
  alter column sample_count drop default;

-- Existing rows were written under the old convention.
update public.health_metric_days d
   set value_avg    = d.value_avg    * 100,
       value_min    = d.value_min    * 100,
       value_max    = d.value_max    * 100,
       value_latest = d.value_latest * 100,
       value_sum    = d.value_sum    * 100,
       unit         = '%'
  from public.metric_catalog c
 where c.metric_key = d.metric_key
   and c.canonical_unit = '%'
   and d.unit <> '%';

-- Whole-number metrics were stored with fractional parts, because a cumulative
-- sum apportions samples that straddle midnight.
update public.health_metric_days d
   set value_sum = round(d.value_sum::numeric)::double precision
  from public.metric_catalog c
 where c.metric_key = d.metric_key
   and c.canonical_unit = 'count'
   and d.value_sum is not null;

-- The count claimed by statistics rows was never real.
update public.health_metric_days
   set sample_count = null
 where sample_count = 1;
