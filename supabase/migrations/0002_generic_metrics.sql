-- HealthKit MCP — generic metric model.
--
-- Why this migration exists
-- ------------------------
-- 0001 modelled a hand-picked set of metrics as fixed columns on health_days
-- (steps, active_energy_kcal, resting_hr_bpm, hrv_sdnn_ms, sleep_minutes).
-- The product requires the user to be able to switch on *any* HealthKit type
-- they own — iOS 26 ships 120 quantity types and 70 category types — so fixed
-- columns cannot work. This migration replaces them with:
--
--   metric_catalog        what a metric is (identifier, unit, how to aggregate)
--   user_metric_settings  which metrics THIS user shares with agents
--   health_metric_days    one row per (user, day, metric)
--
-- The toggle is enforced in the database, not in the app UI: the MCP server
-- reads only the shared_* views, which inner-join user_metric_settings and
-- therefore cannot return a metric the user has not switched on. A toggle that
-- only hides a row in the iOS UI would be security theatre.
--
-- Default for every metric is OFF. Health data is GDPR Art. 9 special
-- category — opt-in, never opt-out.

-- Catalog -------------------------------------------------------------------
create table if not exists public.metric_catalog (
  metric_key     text primary key,
  hk_identifier  text not null unique,
  hk_kind        text not null check (hk_kind in ('quantity', 'category', 'workout')),
  display_name   text not null,
  category       text not null,
  canonical_unit text,
  -- How daily rollups are formed. The iOS app corrects this at runtime from
  -- HKQuantityType.aggregationStyle; the seed below is a sane starting point.
  aggregation    text not null check (aggregation in ('sum', 'avg', 'latest', 'duration', 'count', 'max')),
  -- 'sensitive' metrics are never suggested in bulk-enable flows and are
  -- called out individually in the consent screen.
  sensitivity    text not null default 'standard' check (sensitivity in ('standard', 'sensitive')),
  created_at     timestamptz not null default now()
);

comment on table public.metric_catalog is
  'Every HealthKit type the system knows how to store. Seeded here, extended by the iOS app.';

-- Per-user toggles ----------------------------------------------------------
create table if not exists public.user_metric_settings (
  user_id      uuid not null references auth.users (id) on delete cascade,
  metric_key   text not null references public.metric_catalog (metric_key) on delete cascade,
  enabled      boolean not null default false,
  -- Consent is per metric, captured when the user switches it on.
  consented_at timestamptz,
  updated_at   timestamptz not null default now(),
  primary key (user_id, metric_key)
);

create index if not exists user_metric_settings_enabled_idx
  on public.user_metric_settings (user_id) where enabled;

-- Daily aggregates, long format ---------------------------------------------
create table if not exists public.health_metric_days (
  user_id          uuid not null references auth.users (id) on delete cascade,
  date             date not null,
  metric_key       text not null references public.metric_catalog (metric_key) on delete cascade,
  unit             text not null,
  value_sum        double precision,
  value_avg        double precision,
  value_min        double precision,
  value_max        double precision,
  value_latest     double precision,
  duration_minutes double precision,
  sample_count     integer not null default 0,
  sources          text[],
  updated_at       timestamptz not null default now(),
  primary key (user_id, date, metric_key)
);

create index if not exists health_metric_days_lookup_idx
  on public.health_metric_days (user_id, metric_key, date desc);

-- Catalog seed: every HKQuantityTypeIdentifier in iOS 26 ---------------------
insert into public.metric_catalog
  (metric_key, hk_identifier, hk_kind, display_name, category, canonical_unit, aggregation, sensitivity)
values
  ('body_mass_index','HKQuantityTypeIdentifierBodyMassIndex','quantity','Body Mass Index','body','count','avg','standard'),
  ('body_fat_percentage','HKQuantityTypeIdentifierBodyFatPercentage','quantity','Body Fat Percentage','body','%','avg','standard'),
  ('height','HKQuantityTypeIdentifierHeight','quantity','Height','body','m','latest','standard'),
  ('body_mass','HKQuantityTypeIdentifierBodyMass','quantity','Body Mass','body','kg','avg','standard'),
  ('lean_body_mass','HKQuantityTypeIdentifierLeanBodyMass','quantity','Lean Body Mass','body','kg','avg','standard'),
  ('heart_rate','HKQuantityTypeIdentifierHeartRate','quantity','Heart Rate','heart','count/min','avg','standard'),
  ('step_count','HKQuantityTypeIdentifierStepCount','quantity','Steps','activity','count','sum','standard'),
  ('distance_walking_running','HKQuantityTypeIdentifierDistanceWalkingRunning','quantity','Walking + Running Distance','activity','m','sum','standard'),
  ('distance_cycling','HKQuantityTypeIdentifierDistanceCycling','quantity','Cycling Distance','activity','m','sum','standard'),
  ('basal_energy_burned','HKQuantityTypeIdentifierBasalEnergyBurned','quantity','Resting Energy','activity','kcal','sum','standard'),
  ('active_energy_burned','HKQuantityTypeIdentifierActiveEnergyBurned','quantity','Active Energy','activity','kcal','sum','standard'),
  ('flights_climbed','HKQuantityTypeIdentifierFlightsClimbed','quantity','Flights Climbed','activity','count','sum','standard'),
  ('nike_fuel','HKQuantityTypeIdentifierNikeFuel','quantity','NikeFuel','activity','count','sum','standard'),
  ('oxygen_saturation','HKQuantityTypeIdentifierOxygenSaturation','quantity','Blood Oxygen','vitals','%','avg','standard'),
  ('blood_glucose','HKQuantityTypeIdentifierBloodGlucose','quantity','Blood Glucose','lab','mg/dL','avg','sensitive'),
  ('blood_pressure_systolic','HKQuantityTypeIdentifierBloodPressureSystolic','quantity','Blood Pressure (Systolic)','vitals','mmHg','avg','standard'),
  ('blood_pressure_diastolic','HKQuantityTypeIdentifierBloodPressureDiastolic','quantity','Blood Pressure (Diastolic)','vitals','mmHg','avg','standard'),
  ('blood_alcohol_content','HKQuantityTypeIdentifierBloodAlcoholContent','quantity','Blood Alcohol Content','lab','%','avg','sensitive'),
  ('peripheral_perfusion_index','HKQuantityTypeIdentifierPeripheralPerfusionIndex','quantity','Peripheral Perfusion Index','vitals','%','avg','standard'),
  ('forced_vital_capacity','HKQuantityTypeIdentifierForcedVitalCapacity','quantity','Forced Vital Capacity','respiratory','L','avg','standard'),
  ('forced_expiratory_volume1','HKQuantityTypeIdentifierForcedExpiratoryVolume1','quantity','Forced Expiratory Volume (1s)','respiratory','L','avg','standard'),
  ('peak_expiratory_flow_rate','HKQuantityTypeIdentifierPeakExpiratoryFlowRate','quantity','Peak Expiratory Flow Rate','respiratory','L/min','avg','standard'),
  ('number_of_times_fallen','HKQuantityTypeIdentifierNumberOfTimesFallen','quantity','Number of Times Fallen','mobility','count','sum','standard'),
  ('inhaler_usage','HKQuantityTypeIdentifierInhalerUsage','quantity','Inhaler Usage','respiratory','count','sum','sensitive'),
  ('respiratory_rate','HKQuantityTypeIdentifierRespiratoryRate','quantity','Respiratory Rate','respiratory','count/min','avg','standard'),
  ('body_temperature','HKQuantityTypeIdentifierBodyTemperature','quantity','Body Temperature','vitals','degC','avg','standard'),
  ('dietary_fat_total','HKQuantityTypeIdentifierDietaryFatTotal','quantity','Total Fat','nutrition','g','sum','standard'),
  ('dietary_fat_polyunsaturated','HKQuantityTypeIdentifierDietaryFatPolyunsaturated','quantity','Polyunsaturated Fat','nutrition','g','sum','standard'),
  ('dietary_fat_monounsaturated','HKQuantityTypeIdentifierDietaryFatMonounsaturated','quantity','Monounsaturated Fat','nutrition','g','sum','standard'),
  ('dietary_fat_saturated','HKQuantityTypeIdentifierDietaryFatSaturated','quantity','Saturated Fat','nutrition','g','sum','standard'),
  ('dietary_cholesterol','HKQuantityTypeIdentifierDietaryCholesterol','quantity','Cholesterol','nutrition','mg','sum','standard'),
  ('dietary_sodium','HKQuantityTypeIdentifierDietarySodium','quantity','Sodium','nutrition','mg','sum','standard'),
  ('dietary_carbohydrates','HKQuantityTypeIdentifierDietaryCarbohydrates','quantity','Carbohydrates','nutrition','g','sum','standard'),
  ('dietary_fiber','HKQuantityTypeIdentifierDietaryFiber','quantity','Fiber','nutrition','g','sum','standard'),
  ('dietary_sugar','HKQuantityTypeIdentifierDietarySugar','quantity','Sugar','nutrition','g','sum','standard'),
  ('dietary_energy_consumed','HKQuantityTypeIdentifierDietaryEnergyConsumed','quantity','Dietary Energy','nutrition','kcal','sum','standard'),
  ('dietary_protein','HKQuantityTypeIdentifierDietaryProtein','quantity','Protein','nutrition','g','sum','standard'),
  ('dietary_vitamin_a','HKQuantityTypeIdentifierDietaryVitaminA','quantity','Vitamin A','nutrition','mcg','sum','standard'),
  ('dietary_vitamin_b6','HKQuantityTypeIdentifierDietaryVitaminB6','quantity','Vitamin B6','nutrition','mg','sum','standard'),
  ('dietary_vitamin_b12','HKQuantityTypeIdentifierDietaryVitaminB12','quantity','Vitamin B12','nutrition','mcg','sum','standard'),
  ('dietary_vitamin_c','HKQuantityTypeIdentifierDietaryVitaminC','quantity','Vitamin C','nutrition','mg','sum','standard'),
  ('dietary_vitamin_d','HKQuantityTypeIdentifierDietaryVitaminD','quantity','Vitamin D','nutrition','mcg','sum','standard'),
  ('dietary_vitamin_e','HKQuantityTypeIdentifierDietaryVitaminE','quantity','Vitamin E','nutrition','mg','sum','standard'),
  ('dietary_vitamin_k','HKQuantityTypeIdentifierDietaryVitaminK','quantity','Vitamin K','nutrition','mcg','sum','standard'),
  ('dietary_calcium','HKQuantityTypeIdentifierDietaryCalcium','quantity','Calcium','nutrition','mg','sum','standard'),
  ('dietary_iron','HKQuantityTypeIdentifierDietaryIron','quantity','Iron','nutrition','mg','sum','standard'),
  ('dietary_thiamin','HKQuantityTypeIdentifierDietaryThiamin','quantity','Thiamin','nutrition','mg','sum','standard'),
  ('dietary_riboflavin','HKQuantityTypeIdentifierDietaryRiboflavin','quantity','Riboflavin','nutrition','mg','sum','standard'),
  ('dietary_niacin','HKQuantityTypeIdentifierDietaryNiacin','quantity','Niacin','nutrition','mg','sum','standard'),
  ('dietary_folate','HKQuantityTypeIdentifierDietaryFolate','quantity','Folate','nutrition','mcg','sum','standard'),
  ('dietary_biotin','HKQuantityTypeIdentifierDietaryBiotin','quantity','Biotin','nutrition','mcg','sum','standard'),
  ('dietary_pantothenic_acid','HKQuantityTypeIdentifierDietaryPantothenicAcid','quantity','Pantothenic Acid','nutrition','mg','sum','standard'),
  ('dietary_phosphorus','HKQuantityTypeIdentifierDietaryPhosphorus','quantity','Phosphorus','nutrition','mg','sum','standard'),
  ('dietary_iodine','HKQuantityTypeIdentifierDietaryIodine','quantity','Iodine','nutrition','mcg','sum','standard'),
  ('dietary_magnesium','HKQuantityTypeIdentifierDietaryMagnesium','quantity','Magnesium','nutrition','mg','sum','standard'),
  ('dietary_zinc','HKQuantityTypeIdentifierDietaryZinc','quantity','Zinc','nutrition','mg','sum','standard'),
  ('dietary_selenium','HKQuantityTypeIdentifierDietarySelenium','quantity','Selenium','nutrition','mcg','sum','standard'),
  ('dietary_copper','HKQuantityTypeIdentifierDietaryCopper','quantity','Copper','nutrition','mg','sum','standard'),
  ('dietary_manganese','HKQuantityTypeIdentifierDietaryManganese','quantity','Manganese','nutrition','mg','sum','standard'),
  ('dietary_chromium','HKQuantityTypeIdentifierDietaryChromium','quantity','Chromium','nutrition','mcg','sum','standard'),
  ('dietary_molybdenum','HKQuantityTypeIdentifierDietaryMolybdenum','quantity','Molybdenum','nutrition','mcg','sum','standard'),
  ('dietary_chloride','HKQuantityTypeIdentifierDietaryChloride','quantity','Chloride','nutrition','mg','sum','standard'),
  ('dietary_potassium','HKQuantityTypeIdentifierDietaryPotassium','quantity','Potassium','nutrition','mg','sum','standard'),
  ('dietary_caffeine','HKQuantityTypeIdentifierDietaryCaffeine','quantity','Caffeine','nutrition','mg','sum','standard'),
  ('basal_body_temperature','HKQuantityTypeIdentifierBasalBodyTemperature','quantity','Basal Body Temperature','reproductive','degC','avg','sensitive'),
  ('dietary_water','HKQuantityTypeIdentifierDietaryWater','quantity','Water','nutrition','mL','sum','standard'),
  ('uv_exposure','HKQuantityTypeIdentifierUVExposure','quantity','UV Index','other','count','avg','standard'),
  ('electrodermal_activity','HKQuantityTypeIdentifierElectrodermalActivity','quantity','Electrodermal Activity','other','siemens','avg','standard'),
  ('apple_exercise_time','HKQuantityTypeIdentifierAppleExerciseTime','quantity','Exercise Minutes','activity','min','sum','standard'),
  ('distance_wheelchair','HKQuantityTypeIdentifierDistanceWheelchair','quantity','Wheelchair Distance','activity','m','sum','standard'),
  ('push_count','HKQuantityTypeIdentifierPushCount','quantity','Pushes','activity','count','sum','standard'),
  ('distance_swimming','HKQuantityTypeIdentifierDistanceSwimming','quantity','Swimming Distance','activity','m','sum','standard'),
  ('swimming_stroke_count','HKQuantityTypeIdentifierSwimmingStrokeCount','quantity','Swimming Strokes','activity','count','sum','standard'),
  ('waist_circumference','HKQuantityTypeIdentifierWaistCircumference','quantity','Waist Circumference','body','m','avg','standard'),
  ('vo2_max','HKQuantityTypeIdentifierVO2Max','quantity','VO2 Max','fitness','mL/kg*min','avg','standard'),
  ('distance_downhill_snow_sports','HKQuantityTypeIdentifierDistanceDownhillSnowSports','quantity','Downhill Snow Sports Distance','activity','m','sum','standard'),
  ('insulin_delivery','HKQuantityTypeIdentifierInsulinDelivery','quantity','Insulin Delivery','lab','IU','sum','sensitive'),
  ('resting_heart_rate','HKQuantityTypeIdentifierRestingHeartRate','quantity','Resting Heart Rate','heart','count/min','avg','standard'),
  ('walking_heart_rate_average','HKQuantityTypeIdentifierWalkingHeartRateAverage','quantity','Walking Heart Rate Average','heart','count/min','avg','standard'),
  ('heart_rate_variability_sdnn','HKQuantityTypeIdentifierHeartRateVariabilitySDNN','quantity','Heart Rate Variability (SDNN)','heart','ms','avg','standard'),
  ('apple_stand_time','HKQuantityTypeIdentifierAppleStandTime','quantity','Stand Minutes','activity','min','sum','standard'),
  ('environmental_audio_exposure','HKQuantityTypeIdentifierEnvironmentalAudioExposure','quantity','Environmental Sound Levels','hearing','dBASPL','avg','standard'),
  ('headphone_audio_exposure','HKQuantityTypeIdentifierHeadphoneAudioExposure','quantity','Headphone Audio Levels','hearing','dBASPL','avg','standard'),
  ('six_minute_walk_test_distance','HKQuantityTypeIdentifierSixMinuteWalkTestDistance','quantity','Six-Minute Walk Distance','mobility','m','avg','standard'),
  ('stair_ascent_speed','HKQuantityTypeIdentifierStairAscentSpeed','quantity','Stair Ascent Speed','mobility','m/s','avg','standard'),
  ('stair_descent_speed','HKQuantityTypeIdentifierStairDescentSpeed','quantity','Stair Descent Speed','mobility','m/s','avg','standard'),
  ('walking_asymmetry_percentage','HKQuantityTypeIdentifierWalkingAsymmetryPercentage','quantity','Walking Asymmetry','mobility','%','avg','standard'),
  ('walking_double_support_percentage','HKQuantityTypeIdentifierWalkingDoubleSupportPercentage','quantity','Double Support Time','mobility','%','avg','standard'),
  ('walking_speed','HKQuantityTypeIdentifierWalkingSpeed','quantity','Walking Speed','mobility','m/s','avg','standard'),
  ('walking_step_length','HKQuantityTypeIdentifierWalkingStepLength','quantity','Walking Step Length','mobility','m','avg','standard'),
  ('apple_move_time','HKQuantityTypeIdentifierAppleMoveTime','quantity','Move Minutes','activity','min','sum','standard'),
  ('apple_walking_steadiness','HKQuantityTypeIdentifierAppleWalkingSteadiness','quantity','Walking Steadiness','mobility','%','avg','standard'),
  ('number_of_alcoholic_beverages','HKQuantityTypeIdentifierNumberOfAlcoholicBeverages','quantity','Alcoholic Beverages','nutrition','count','sum','sensitive'),
  ('heart_rate_recovery_one_minute','HKQuantityTypeIdentifierHeartRateRecoveryOneMinute','quantity','Cardio Recovery','heart','count/min','avg','standard'),
  ('running_ground_contact_time','HKQuantityTypeIdentifierRunningGroundContactTime','quantity','Ground Contact Time','fitness','ms','avg','standard'),
  ('running_stride_length','HKQuantityTypeIdentifierRunningStrideLength','quantity','Running Stride Length','fitness','m','avg','standard'),
  ('running_vertical_oscillation','HKQuantityTypeIdentifierRunningVerticalOscillation','quantity','Vertical Oscillation','fitness','cm','avg','standard'),
  ('running_power','HKQuantityTypeIdentifierRunningPower','quantity','Running Power','fitness','W','avg','standard'),
  ('running_speed','HKQuantityTypeIdentifierRunningSpeed','quantity','Running Speed','fitness','m/s','avg','standard'),
  ('atrial_fibrillation_burden','HKQuantityTypeIdentifierAtrialFibrillationBurden','quantity','AFib History','heart','%','avg','sensitive'),
  ('apple_sleeping_wrist_temperature','HKQuantityTypeIdentifierAppleSleepingWristTemperature','quantity','Wrist Temperature','sleep','degC','avg','standard'),
  ('underwater_depth','HKQuantityTypeIdentifierUnderwaterDepth','quantity','Underwater Depth','fitness','m','max','standard'),
  ('water_temperature','HKQuantityTypeIdentifierWaterTemperature','quantity','Water Temperature','other','degC','avg','standard'),
  ('cycling_cadence','HKQuantityTypeIdentifierCyclingCadence','quantity','Cycling Cadence','fitness','count/min','avg','standard'),
  ('cycling_functional_threshold_power','HKQuantityTypeIdentifierCyclingFunctionalThresholdPower','quantity','Cycling FTP','fitness','W','avg','standard'),
  ('cycling_power','HKQuantityTypeIdentifierCyclingPower','quantity','Cycling Power','fitness','W','avg','standard'),
  ('cycling_speed','HKQuantityTypeIdentifierCyclingSpeed','quantity','Cycling Speed','fitness','m/s','avg','standard'),
  ('environmental_sound_reduction','HKQuantityTypeIdentifierEnvironmentalSoundReduction','quantity','Environmental Sound Reduction','hearing','dBASPL','avg','standard'),
  ('physical_effort','HKQuantityTypeIdentifierPhysicalEffort','quantity','Physical Effort','activity','kcal/kg*hr','avg','standard'),
  ('time_in_daylight','HKQuantityTypeIdentifierTimeInDaylight','quantity','Time in Daylight','activity','min','sum','standard'),
  ('workout_effort_score','HKQuantityTypeIdentifierWorkoutEffortScore','quantity','Workout Effort Score','fitness','effortScore','avg','standard'),
  ('cross_country_skiing_speed','HKQuantityTypeIdentifierCrossCountrySkiingSpeed','quantity','Cross-Country Skiing Speed','fitness','m/s','avg','standard'),
  ('distance_cross_country_skiing','HKQuantityTypeIdentifierDistanceCrossCountrySkiing','quantity','Cross-Country Skiing Distance','activity','m','sum','standard'),
  ('distance_paddle_sports','HKQuantityTypeIdentifierDistancePaddleSports','quantity','Paddle Sports Distance','activity','m','sum','standard'),
  ('distance_rowing','HKQuantityTypeIdentifierDistanceRowing','quantity','Rowing Distance','activity','m','sum','standard'),
  ('distance_skating_sports','HKQuantityTypeIdentifierDistanceSkatingSports','quantity','Skating Sports Distance','activity','m','sum','standard'),
  ('estimated_workout_effort_score','HKQuantityTypeIdentifierEstimatedWorkoutEffortScore','quantity','Estimated Workout Effort','fitness','effortScore','avg','standard'),
  ('paddle_sports_speed','HKQuantityTypeIdentifierPaddleSportsSpeed','quantity','Paddle Sports Speed','fitness','m/s','avg','standard'),
  ('rowing_speed','HKQuantityTypeIdentifierRowingSpeed','quantity','Rowing Speed','fitness','m/s','avg','standard'),
  ('apple_sleeping_breathing_disturbances','HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances','quantity','Breathing Disturbances','sleep','count','avg','standard')
on conflict (metric_key) do nothing;

-- Catalog seed: every HKCategoryTypeIdentifier in iOS 26 ---------------------
-- Symptom and reproductive-health types are marked sensitive: they are the
-- most revealing data in HealthKit and must never be bulk-enabled.
insert into public.metric_catalog
  (metric_key, hk_identifier, hk_kind, display_name, category, canonical_unit, aggregation, sensitivity)
values
  ('sleep_analysis','HKCategoryTypeIdentifierSleepAnalysis','category','Sleep Analysis','sleep','min','duration','standard'),
  ('apple_stand_hour','HKCategoryTypeIdentifierAppleStandHour','category','Stand Hours','activity','count','count','standard'),
  ('cervical_mucus_quality','HKCategoryTypeIdentifierCervicalMucusQuality','category','Cervical Mucus Quality','reproductive',null,'latest','sensitive'),
  ('ovulation_test_result','HKCategoryTypeIdentifierOvulationTestResult','category','Ovulation Test Result','reproductive',null,'latest','sensitive'),
  ('menstrual_flow','HKCategoryTypeIdentifierMenstrualFlow','category','Menstrual Flow','reproductive',null,'latest','sensitive'),
  ('intermenstrual_bleeding','HKCategoryTypeIdentifierIntermenstrualBleeding','category','Intermenstrual Bleeding','reproductive',null,'latest','sensitive'),
  ('sexual_activity','HKCategoryTypeIdentifierSexualActivity','category','Sexual Activity','reproductive','count','count','sensitive'),
  ('mindful_session','HKCategoryTypeIdentifierMindfulSession','category','Mindful Minutes','mindfulness','min','duration','standard'),
  ('high_heart_rate_event','HKCategoryTypeIdentifierHighHeartRateEvent','category','High Heart Rate Events','heart','count','count','standard'),
  ('low_heart_rate_event','HKCategoryTypeIdentifierLowHeartRateEvent','category','Low Heart Rate Events','heart','count','count','standard'),
  ('irregular_heart_rhythm_event','HKCategoryTypeIdentifierIrregularHeartRhythmEvent','category','Irregular Rhythm Events','heart','count','count','sensitive'),
  ('audio_exposure_event','HKCategoryTypeIdentifierAudioExposureEvent','category','Audio Exposure Events','hearing','count','count','standard'),
  ('toothbrushing_event','HKCategoryTypeIdentifierToothbrushingEvent','category','Toothbrushing','other','min','duration','standard'),
  ('abdominal_cramps','HKCategoryTypeIdentifierAbdominalCramps','category','Abdominal Cramps','symptoms','count','count','sensitive'),
  ('acne','HKCategoryTypeIdentifierAcne','category','Acne','symptoms','count','count','sensitive'),
  ('appetite_changes','HKCategoryTypeIdentifierAppetiteChanges','category','Appetite Changes','symptoms','count','count','sensitive'),
  ('generalized_body_ache','HKCategoryTypeIdentifierGeneralizedBodyAche','category','Body and Muscle Ache','symptoms','count','count','sensitive'),
  ('bloating','HKCategoryTypeIdentifierBloating','category','Bloating','symptoms','count','count','sensitive'),
  ('breast_pain','HKCategoryTypeIdentifierBreastPain','category','Breast Pain','symptoms','count','count','sensitive'),
  ('chest_tightness_or_pain','HKCategoryTypeIdentifierChestTightnessOrPain','category','Chest Tightness or Pain','symptoms','count','count','sensitive'),
  ('chills','HKCategoryTypeIdentifierChills','category','Chills','symptoms','count','count','sensitive'),
  ('constipation','HKCategoryTypeIdentifierConstipation','category','Constipation','symptoms','count','count','sensitive'),
  ('coughing','HKCategoryTypeIdentifierCoughing','category','Coughing','symptoms','count','count','sensitive'),
  ('diarrhea','HKCategoryTypeIdentifierDiarrhea','category','Diarrhea','symptoms','count','count','sensitive'),
  ('dizziness','HKCategoryTypeIdentifierDizziness','category','Dizziness','symptoms','count','count','sensitive'),
  ('fainting','HKCategoryTypeIdentifierFainting','category','Fainting','symptoms','count','count','sensitive'),
  ('fatigue','HKCategoryTypeIdentifierFatigue','category','Fatigue','symptoms','count','count','sensitive'),
  ('fever','HKCategoryTypeIdentifierFever','category','Fever','symptoms','count','count','sensitive'),
  ('headache','HKCategoryTypeIdentifierHeadache','category','Headache','symptoms','count','count','sensitive'),
  ('heartburn','HKCategoryTypeIdentifierHeartburn','category','Heartburn','symptoms','count','count','sensitive'),
  ('hot_flashes','HKCategoryTypeIdentifierHotFlashes','category','Hot Flashes','symptoms','count','count','sensitive'),
  ('lower_back_pain','HKCategoryTypeIdentifierLowerBackPain','category','Lower Back Pain','symptoms','count','count','sensitive'),
  ('loss_of_smell','HKCategoryTypeIdentifierLossOfSmell','category','Loss of Smell','symptoms','count','count','sensitive'),
  ('loss_of_taste','HKCategoryTypeIdentifierLossOfTaste','category','Loss of Taste','symptoms','count','count','sensitive'),
  ('mood_changes','HKCategoryTypeIdentifierMoodChanges','category','Mood Changes','symptoms','count','count','sensitive'),
  ('nausea','HKCategoryTypeIdentifierNausea','category','Nausea','symptoms','count','count','sensitive'),
  ('pelvic_pain','HKCategoryTypeIdentifierPelvicPain','category','Pelvic Pain','symptoms','count','count','sensitive'),
  ('rapid_pounding_or_fluttering_heartbeat','HKCategoryTypeIdentifierRapidPoundingOrFlutteringHeartbeat','category','Rapid or Fluttering Heartbeat','symptoms','count','count','sensitive'),
  ('runny_nose','HKCategoryTypeIdentifierRunnyNose','category','Runny Nose','symptoms','count','count','sensitive'),
  ('shortness_of_breath','HKCategoryTypeIdentifierShortnessOfBreath','category','Shortness of Breath','symptoms','count','count','sensitive'),
  ('sinus_congestion','HKCategoryTypeIdentifierSinusCongestion','category','Sinus Congestion','symptoms','count','count','sensitive'),
  ('skipped_heartbeat','HKCategoryTypeIdentifierSkippedHeartbeat','category','Skipped Heartbeat','symptoms','count','count','sensitive'),
  ('sleep_changes','HKCategoryTypeIdentifierSleepChanges','category','Sleep Changes','symptoms','count','count','sensitive'),
  ('sore_throat','HKCategoryTypeIdentifierSoreThroat','category','Sore Throat','symptoms','count','count','sensitive'),
  ('vomiting','HKCategoryTypeIdentifierVomiting','category','Vomiting','symptoms','count','count','sensitive'),
  ('wheezing','HKCategoryTypeIdentifierWheezing','category','Wheezing','symptoms','count','count','sensitive'),
  ('bladder_incontinence','HKCategoryTypeIdentifierBladderIncontinence','category','Bladder Incontinence','symptoms','count','count','sensitive'),
  ('dry_skin','HKCategoryTypeIdentifierDrySkin','category','Dry Skin','symptoms','count','count','sensitive'),
  ('hair_loss','HKCategoryTypeIdentifierHairLoss','category','Hair Loss','symptoms','count','count','sensitive'),
  ('vaginal_dryness','HKCategoryTypeIdentifierVaginalDryness','category','Vaginal Dryness','symptoms','count','count','sensitive'),
  ('memory_lapse','HKCategoryTypeIdentifierMemoryLapse','category','Memory Lapse','symptoms','count','count','sensitive'),
  ('night_sweats','HKCategoryTypeIdentifierNightSweats','category','Night Sweats','symptoms','count','count','sensitive'),
  ('environmental_audio_exposure_event','HKCategoryTypeIdentifierEnvironmentalAudioExposureEvent','category','Loud Environment Events','hearing','count','count','standard'),
  ('handwashing_event','HKCategoryTypeIdentifierHandwashingEvent','category','Handwashing','other','min','duration','standard'),
  ('headphone_audio_exposure_event','HKCategoryTypeIdentifierHeadphoneAudioExposureEvent','category','Loud Headphone Events','hearing','count','count','standard'),
  ('pregnancy','HKCategoryTypeIdentifierPregnancy','category','Pregnancy','reproductive',null,'latest','sensitive'),
  ('lactation','HKCategoryTypeIdentifierLactation','category','Lactation','reproductive',null,'latest','sensitive'),
  ('contraceptive','HKCategoryTypeIdentifierContraceptive','category','Contraceptive','reproductive',null,'latest','sensitive'),
  ('low_cardio_fitness_event','HKCategoryTypeIdentifierLowCardioFitnessEvent','category','Low Cardio Fitness Events','fitness','count','count','standard'),
  ('apple_walking_steadiness_event','HKCategoryTypeIdentifierAppleWalkingSteadinessEvent','category','Walking Steadiness Events','mobility','count','count','standard'),
  ('pregnancy_test_result','HKCategoryTypeIdentifierPregnancyTestResult','category','Pregnancy Test Result','reproductive',null,'latest','sensitive'),
  ('progesterone_test_result','HKCategoryTypeIdentifierProgesteroneTestResult','category','Progesterone Test Result','reproductive',null,'latest','sensitive'),
  ('infrequent_menstrual_cycles','HKCategoryTypeIdentifierInfrequentMenstrualCycles','category','Infrequent Periods','reproductive',null,'latest','sensitive'),
  ('irregular_menstrual_cycles','HKCategoryTypeIdentifierIrregularMenstrualCycles','category','Irregular Cycles','reproductive',null,'latest','sensitive'),
  ('persistent_intermenstrual_bleeding','HKCategoryTypeIdentifierPersistentIntermenstrualBleeding','category','Persistent Intermenstrual Bleeding','reproductive',null,'latest','sensitive'),
  ('prolonged_menstrual_periods','HKCategoryTypeIdentifierProlongedMenstrualPeriods','category','Prolonged Periods','reproductive',null,'latest','sensitive'),
  ('bleeding_after_pregnancy','HKCategoryTypeIdentifierBleedingAfterPregnancy','category','Bleeding After Pregnancy','reproductive',null,'latest','sensitive'),
  ('bleeding_during_pregnancy','HKCategoryTypeIdentifierBleedingDuringPregnancy','category','Bleeding During Pregnancy','reproductive',null,'latest','sensitive'),
  ('sleep_apnea_event','HKCategoryTypeIdentifierSleepApneaEvent','category','Sleep Apnea Notifications','sleep','count','count','sensitive'),
  ('hypertension_event','HKCategoryTypeIdentifierHypertensionEvent','category','Hypertension Notifications','vitals','count','count','sensitive'),
  -- Pseudo-metric: gates the workouts table through the same toggle mechanism.
  ('workouts','HKWorkoutTypeIdentifier','workout','Workouts','activity','count','count','standard')
on conflict (metric_key) do nothing;

-- Retire health_days --------------------------------------------------------
-- Carry any rows written under 0001 into the generic table before dropping it,
-- so an installation that already applied 0001 does not lose data.
insert into public.health_metric_days (user_id, date, metric_key, unit, value_sum, sample_count)
select user_id, date, 'step_count', 'count', steps, 1
from public.health_days where steps is not null
on conflict do nothing;

insert into public.health_metric_days (user_id, date, metric_key, unit, value_sum, sample_count)
select user_id, date, 'active_energy_burned', 'kcal', active_energy_kcal, 1
from public.health_days where active_energy_kcal is not null
on conflict do nothing;

insert into public.health_metric_days (user_id, date, metric_key, unit, value_avg, sample_count)
select user_id, date, 'resting_heart_rate', 'count/min', resting_hr_bpm, 1
from public.health_days where resting_hr_bpm is not null
on conflict do nothing;

insert into public.health_metric_days (user_id, date, metric_key, unit, value_avg, sample_count)
select user_id, date, 'heart_rate_variability_sdnn', 'ms', hrv_sdnn_ms, 1
from public.health_days where hrv_sdnn_ms is not null
on conflict do nothing;

insert into public.health_metric_days (user_id, date, metric_key, unit, duration_minutes, sample_count)
select user_id, date, 'sleep_analysis', 'min', sleep_minutes, 1
from public.health_days where sleep_minutes is not null
on conflict do nothing;

drop table if exists public.health_days;

-- Consent-enforcing views ---------------------------------------------------
-- The MCP server reads ONLY these. The inner join on user_metric_settings is
-- the enforcement point: a metric the user has not switched on cannot be
-- selected, regardless of what the server code asks for. The service-role key
-- bypasses RLS but it cannot bypass a join.
create or replace view public.shared_metric_days
with (security_invoker = on) as
select
  d.user_id, d.date, d.metric_key, c.display_name, c.category,
  c.aggregation, c.sensitivity, d.unit,
  -- One canonical value per metric, chosen by the catalog's aggregation rule,
  -- so every consumer agrees on what "the value for that day" means.
  case c.aggregation
    when 'sum'      then d.value_sum
    when 'avg'      then d.value_avg
    when 'latest'   then d.value_latest
    when 'duration' then d.duration_minutes
    when 'max'      then d.value_max
    when 'count'    then coalesce(d.value_sum, d.sample_count::double precision)
  end as value,
  d.value_sum, d.value_avg, d.value_min, d.value_max,
  d.value_latest, d.duration_minutes, d.sample_count, d.sources, d.updated_at
from public.health_metric_days d
join public.user_metric_settings s
  on s.user_id = d.user_id and s.metric_key = d.metric_key and s.enabled
join public.metric_catalog c
  on c.metric_key = d.metric_key;

-- What the agent is allowed to know exists at all. Metrics the user has not
-- switched on are invisible, not merely empty.
create or replace view public.shared_metrics
with (security_invoker = on) as
select
  s.user_id, c.metric_key, c.display_name, c.category, c.hk_kind,
  c.canonical_unit, c.aggregation, c.sensitivity, s.consented_at
from public.user_metric_settings s
join public.metric_catalog c on c.metric_key = s.metric_key
where s.enabled;

create or replace view public.shared_sleep_nights
with (security_invoker = on) as
select n.*
from public.sleep_nights n
join public.user_metric_settings s
  on s.user_id = n.user_id and s.metric_key = 'sleep_analysis' and s.enabled;

create or replace view public.shared_workouts
with (security_invoker = on) as
select w.*
from public.workouts w
join public.user_metric_settings s
  on s.user_id = w.user_id and s.metric_key = 'workouts' and s.enabled;

-- Row-Level Security --------------------------------------------------------
alter table public.metric_catalog       enable row level security;
alter table public.user_metric_settings enable row level security;
alter table public.health_metric_days   enable row level security;

-- The catalog is reference data: readable by any signed-in user, written only
-- by the service role (which bypasses RLS, so no write policy is needed).
create policy "read metric catalog" on public.metric_catalog
  for select to authenticated using (true);

create policy "own metric settings" on public.user_metric_settings
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own metric days" on public.health_metric_days
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
