"""German display names for the metric catalog, keyed by metric_key.

Terminology follows Apple's own German Health app wording where it exists, so
the picker reads the same as the system app the data comes from.
"""
DE = {
# activity
"step_count":"Schritte","distance_walking_running":"Geh- und Laufstrecke","distance_cycling":"Radfahrstrecke",
"basal_energy_burned":"Ruheenergie","active_energy_burned":"Aktive Energie","flights_climbed":"Stockwerke",
"nike_fuel":"NikeFuel","apple_exercise_time":"Bewegungsminuten","distance_wheelchair":"Rollstuhlstrecke",
"push_count":"Anschübe","distance_swimming":"Schwimmstrecke","swimming_stroke_count":"Schwimmzüge",
"distance_downhill_snow_sports":"Ski- und Snowboardstrecke","apple_stand_time":"Stehminuten",
"apple_move_time":"Bewegungszeit","physical_effort":"Körperliche Anstrengung","time_in_daylight":"Zeit im Tageslicht",
"distance_cross_country_skiing":"Langlaufstrecke","distance_paddle_sports":"Paddelstrecke",
"distance_rowing":"Ruderstrecke","distance_skating_sports":"Skatingstrecke","apple_stand_hour":"Stehstunden",
"workouts":"Trainings",
# body
"body_mass_index":"Body-Mass-Index","body_fat_percentage":"Körperfettanteil","height":"Körpergröße",
"body_mass":"Gewicht","lean_body_mass":"Magermasse","waist_circumference":"Taillenumfang",
# heart
"heart_rate":"Herzfrequenz","resting_heart_rate":"Ruhepuls","walking_heart_rate_average":"Durchschnittliche Herzfrequenz beim Gehen",
"heart_rate_variability_sdnn":"Herzfrequenzvariabilität (SDNN)","heart_rate_recovery_one_minute":"Kardio-Erholung",
"atrial_fibrillation_burden":"Vorhofflimmern-Verlauf","high_heart_rate_event":"Ereignisse mit hoher Herzfrequenz",
"low_heart_rate_event":"Ereignisse mit niedriger Herzfrequenz","irregular_heart_rhythm_event":"Unregelmäßiger Rhythmus",
# vitals
"oxygen_saturation":"Blutsauerstoff","blood_pressure_systolic":"Blutdruck (systolisch)",
"blood_pressure_diastolic":"Blutdruck (diastolisch)","peripheral_perfusion_index":"Peripherer Perfusionsindex",
"body_temperature":"Körpertemperatur","hypertension_event":"Bluthochdruck-Mitteilungen",
# respiratory
"forced_vital_capacity":"Forcierte Vitalkapazität","forced_expiratory_volume1":"Einsekundenkapazität (FEV1)",
"peak_expiratory_flow_rate":"Maximaler exspiratorischer Fluss","inhaler_usage":"Inhalator-Nutzung",
"respiratory_rate":"Atemfrequenz",
# lab
"blood_glucose":"Blutzucker","blood_alcohol_content":"Blutalkoholgehalt","insulin_delivery":"Insulinabgabe",
# fitness
"vo2_max":"VO2max","running_ground_contact_time":"Bodenkontaktzeit","running_stride_length":"Schrittlänge beim Laufen",
"running_vertical_oscillation":"Vertikale Bewegung","running_power":"Laufleistung","running_speed":"Laufgeschwindigkeit",
"underwater_depth":"Tauchtiefe","cycling_cadence":"Trittfrequenz","cycling_functional_threshold_power":"Funktionelle Schwellenleistung",
"cycling_power":"Radfahrleistung","cycling_speed":"Radfahrgeschwindigkeit","workout_effort_score":"Trainingsanstrengung",
"cross_country_skiing_speed":"Langlaufgeschwindigkeit","estimated_workout_effort_score":"Geschätzte Trainingsanstrengung",
"paddle_sports_speed":"Paddelgeschwindigkeit","rowing_speed":"Rudergeschwindigkeit",
"low_cardio_fitness_event":"Geringe Kardiofitness",
# mobility
"number_of_times_fallen":"Stürze","six_minute_walk_test_distance":"Gehstrecke in 6 Minuten",
"stair_ascent_speed":"Geschwindigkeit beim Treppensteigen","stair_descent_speed":"Geschwindigkeit beim Treppabgehen",
"walking_asymmetry_percentage":"Gehasymmetrie","walking_double_support_percentage":"Doppelstandphase",
"walking_speed":"Gehgeschwindigkeit","walking_step_length":"Schrittlänge","apple_walking_steadiness":"Gehstabilität",
"apple_walking_steadiness_event":"Gehstabilitäts-Mitteilungen",
# sleep
"sleep_analysis":"Schlafanalyse","apple_sleeping_wrist_temperature":"Handgelenktemperatur",
"apple_sleeping_breathing_disturbances":"Atemstörungen im Schlaf","sleep_apnea_event":"Schlafapnoe-Mitteilungen",
# hearing
"environmental_audio_exposure":"Umgebungslautstärke","headphone_audio_exposure":"Kopfhörerlautstärke",
"environmental_sound_reduction":"Reduzierung von Umgebungsgeräuschen","audio_exposure_event":"Lautstärke-Ereignisse",
"environmental_audio_exposure_event":"Laute Umgebung","headphone_audio_exposure_event":"Laute Kopfhörer",
# mindfulness / other
"mindful_session":"Achtsamkeitsminuten","toothbrushing_event":"Zähneputzen","handwashing_event":"Händewaschen",
"uv_exposure":"UV-Index","electrodermal_activity":"Elektrodermale Aktivität","water_temperature":"Wassertemperatur",
# reproductive
"basal_body_temperature":"Basaltemperatur","cervical_mucus_quality":"Zervixschleim","ovulation_test_result":"Ovulationstest",
"menstrual_flow":"Menstruationsfluss","intermenstrual_bleeding":"Zwischenblutung","sexual_activity":"Sexuelle Aktivität",
"pregnancy":"Schwangerschaft","lactation":"Stillzeit","contraceptive":"Verhütung","pregnancy_test_result":"Schwangerschaftstest",
"progesterone_test_result":"Progesterontest","infrequent_menstrual_cycles":"Seltene Perioden",
"irregular_menstrual_cycles":"Unregelmäßige Zyklen","persistent_intermenstrual_bleeding":"Anhaltende Zwischenblutungen",
"prolonged_menstrual_periods":"Verlängerte Perioden","bleeding_after_pregnancy":"Blutung nach Schwangerschaft",
"bleeding_during_pregnancy":"Blutung während Schwangerschaft",
# symptoms
"abdominal_cramps":"Bauchkrämpfe","acne":"Akne","appetite_changes":"Appetitveränderungen",
"generalized_body_ache":"Körper- und Muskelschmerzen","bloating":"Blähbauch","breast_pain":"Brustschmerzen",
"chest_tightness_or_pain":"Engegefühl oder Schmerzen in der Brust","chills":"Schüttelfrost","constipation":"Verstopfung",
"coughing":"Husten","diarrhea":"Durchfall","dizziness":"Schwindel","fainting":"Ohnmacht","fatigue":"Müdigkeit",
"fever":"Fieber","headache":"Kopfschmerzen","heartburn":"Sodbrennen","hot_flashes":"Hitzewallungen",
"lower_back_pain":"Schmerzen im unteren Rücken","loss_of_smell":"Geruchsverlust","loss_of_taste":"Geschmacksverlust",
"mood_changes":"Stimmungsschwankungen","nausea":"Übelkeit","pelvic_pain":"Beckenschmerzen",
"rapid_pounding_or_fluttering_heartbeat":"Schneller oder flatternder Herzschlag","runny_nose":"Laufende Nase",
"shortness_of_breath":"Kurzatmigkeit","sinus_congestion":"Verstopfte Nebenhöhlen","skipped_heartbeat":"Herzstolpern",
"sleep_changes":"Veränderter Schlaf","sore_throat":"Halsschmerzen","vomiting":"Erbrechen","wheezing":"Pfeifende Atmung",
"bladder_incontinence":"Blasenschwäche","dry_skin":"Trockene Haut","hair_loss":"Haarausfall",
"vaginal_dryness":"Vaginale Trockenheit","memory_lapse":"Gedächtnislücken","night_sweats":"Nachtschweiß",
# nutrition
"dietary_fat_total":"Fett gesamt","dietary_fat_polyunsaturated":"Mehrfach ungesättigte Fettsäuren",
"dietary_fat_monounsaturated":"Einfach ungesättigte Fettsäuren","dietary_fat_saturated":"Gesättigte Fettsäuren",
"dietary_cholesterol":"Cholesterin","dietary_sodium":"Natrium","dietary_carbohydrates":"Kohlenhydrate",
"dietary_fiber":"Ballaststoffe","dietary_sugar":"Zucker","dietary_energy_consumed":"Aufgenommene Energie",
"dietary_protein":"Protein","dietary_vitamin_a":"Vitamin A","dietary_vitamin_b6":"Vitamin B6",
"dietary_vitamin_b12":"Vitamin B12","dietary_vitamin_c":"Vitamin C","dietary_vitamin_d":"Vitamin D",
"dietary_vitamin_e":"Vitamin E","dietary_vitamin_k":"Vitamin K","dietary_calcium":"Kalzium","dietary_iron":"Eisen",
"dietary_thiamin":"Thiamin","dietary_riboflavin":"Riboflavin","dietary_niacin":"Niacin","dietary_folate":"Folsäure",
"dietary_biotin":"Biotin","dietary_pantothenic_acid":"Pantothensäure","dietary_phosphorus":"Phosphor",
"dietary_iodine":"Jod","dietary_magnesium":"Magnesium","dietary_zinc":"Zink","dietary_selenium":"Selen",
"dietary_copper":"Kupfer","dietary_manganese":"Mangan","dietary_chromium":"Chrom","dietary_molybdenum":"Molybdän",
"dietary_chloride":"Chlorid","dietary_potassium":"Kalium","dietary_caffeine":"Koffein","dietary_water":"Wasser",
"number_of_alcoholic_beverages":"Alkoholische Getränke",
}
