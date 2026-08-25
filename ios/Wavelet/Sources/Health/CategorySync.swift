import Foundation
import HealthKit

/// Category types and workouts.
///
/// Quantity types collapse neatly into HealthKit's own statistics collections;
/// categories do not, so their samples are fetched and folded by hand.
enum CategorySync {
    /// A sleep session belongs to the morning the user woke up, which is the
    /// day its sample *ends* — a 23:00–07:00 night lands on the 07:00 date, and
    /// an afternoon nap lands on its own day.
    static func nightDate(for sample: HKCategorySample, calendar: Calendar) -> Date {
        calendar.startOfDay(for: sample.endDate)
    }

    static func fetchSamples(
        store: HKHealthStore,
        type: HKSampleType,
        start: Date,
        end: Date,
    ) async throws -> [HKSample] {
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)],
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            store.execute(query)
        }
    }

    /// Minutes per sleep stage, per night.
    static func sleepNights(
        from samples: [HKSample],
        userId: String,
        calendar: Calendar,
    ) -> ([SleepNightRow], [MetricDayRow]) {
        var nights: [Date: SleepTotals] = [:]

        for case let sample as HKCategorySample in samples {
            let night = nightDate(for: sample, calendar: calendar)
            let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60
            var totals = nights[night] ?? SleepTotals()

            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .inBed:             totals.inBed += minutes
            case .asleepCore:        totals.core += minutes;  totals.asleep += minutes
            case .asleepDeep:        totals.deep += minutes;  totals.asleep += minutes
            case .asleepREM:         totals.rem += minutes;   totals.asleep += minutes
            case .asleepUnspecified: totals.asleep += minutes
            case .awake:             totals.awake += minutes
            default:                 break
            }
            nights[night] = totals
        }

        let nightRows = nights.map { night, t in
            SleepNightRow(
                user_id: userId,
                date: SyncFormat.day.string(from: night),
                in_bed_minutes: t.inBed > 0 ? Int(t.inBed.rounded()) : nil,
                asleep_minutes: t.asleep > 0 ? Int(t.asleep.rounded()) : nil,
                rem_minutes: t.rem > 0 ? Int(t.rem.rounded()) : nil,
                deep_minutes: t.deep > 0 ? Int(t.deep.rounded()) : nil,
                core_minutes: t.core > 0 ? Int(t.core.rounded()) : nil,
                awake_minutes: t.awake > 0 ? Int(t.awake.rounded()) : nil,
            )
        }

        // Also expose sleep as a daily metric so it appears in trends and the
        // daily summary alongside everything else.
        let dayRows = nights.compactMap { night, t -> MetricDayRow? in
            guard t.asleep > 0 else { return nil }
            return MetricDayRow(
                user_id: userId,
                date: SyncFormat.day.string(from: night),
                metric_key: "sleep_analysis",
                unit: "min",
                value_sum: nil, value_avg: nil, value_min: nil,
                value_max: nil, value_latest: nil,
                duration_minutes: t.asleep.rounded(),
                sample_count: nil,
                sources: nil,
            )
        }
        return (nightRows, dayRows)
    }

    /// Non-sleep categories: duration types are summed, event types counted.
    static func categoryDays(
        from samples: [HKSample],
        metric: MetricDescriptor,
        userId: String,
        calendar: Calendar,
    ) -> [MetricDayRow] {
        var perDay: [Date: (duration: Double, count: Int)] = [:]
        for case let sample as HKCategorySample in samples {
            let day = calendar.startOfDay(for: sample.startDate)
            var entry = perDay[day] ?? (0, 0)
            entry.duration += sample.endDate.timeIntervalSince(sample.startDate) / 60
            entry.count += 1
            perDay[day] = entry
        }

        return perDay.map { day, entry in
            MetricDayRow(
                user_id: userId,
                date: SyncFormat.day.string(from: day),
                metric_key: metric.key,
                unit: metric.unit ?? "count",
                value_sum: metric.aggregation == .count ? Double(entry.count) : nil,
                value_avg: nil, value_min: nil, value_max: nil, value_latest: nil,
                duration_minutes: metric.aggregation == .duration ? entry.duration.rounded() : nil,
                sample_count: entry.count,
                sources: nil,
            )
        }
    }

    /// Every distance type a workout might record, most common first.
    private static let distanceTypes: [HKQuantityType] = {
        var types: [HKQuantityType] = [
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.distanceDownhillSnowSports),
            HKQuantityType(.distanceWheelchair),
        ]
        // Added in iOS 18; the app still supports 17.
        if #available(iOS 18.0, *) {
            types += [
                HKQuantityType(.distanceCrossCountrySkiing),
                HKQuantityType(.distanceRowing),
                HKQuantityType(.distancePaddleSports),
                HKQuantityType(.distanceSkatingSports),
            ]
        }
        return types
    }()

    /// Workouts per day, so `workouts` behaves like any other trend metric
    /// instead of being listed but always empty.
    static func workoutDays(
        from rows: [WorkoutRow],
        userId: String,
        calendar: Calendar,
    ) -> [MetricDayRow] {
        var perDay: [String: (count: Int, sources: Set<String>)] = [:]
        for row in rows {
            let day = String(row.start_at.prefix(10))
            var entry = perDay[day] ?? (0, [])
            entry.count += 1
            if let source = row.source { entry.sources.insert(source) }
            perDay[day] = entry
        }
        return perDay.map { day, entry in
            MetricDayRow(
                user_id: userId,
                date: day,
                metric_key: "workouts",
                unit: "count",
                value_sum: Double(entry.count),
                value_avg: nil, value_min: nil, value_max: nil, value_latest: nil,
                duration_minutes: nil,
                sample_count: entry.count,
                sources: entry.sources.isEmpty ? nil : entry.sources.sorted(),
            )
        }
    }

    static func workoutRows(from samples: [HKSample], userId: String) -> [WorkoutRow] {
        samples.compactMap { sample in
            guard let workout = sample as? HKWorkout else { return nil }
            // A workout's distance lives under whichever distance type matches
            // the activity, so asking only for walking/running left every ride
            // and swim with a null distance.
            let distance = distanceTypes
                .lazy
                .compactMap { workout.statistics(for: $0)?.sumQuantity()?.doubleValue(for: .meter()) }
                .first
            let energy = workout
                .statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie())
            let heartRate = workout
                .statistics(for: HKQuantityType(.heartRate))?
                .averageQuantity()?
                .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

            return WorkoutRow(
                id: workout.uuid.uuidString,
                user_id: userId,
                type: workout.workoutActivityType.slug,
                start_at: SyncFormat.timestamp.string(from: workout.startDate),
                end_at: SyncFormat.timestamp.string(from: workout.endDate),
                duration_seconds: Int(workout.duration.rounded()),
                distance_meters: distance.map { Int($0.rounded()) },
                active_energy_kcal: energy.map { Int($0.rounded()) },
                avg_hr_bpm: heartRate.map { Int($0.rounded()) },
                source: workout.sourceRevision.source.name,
            )
        }
    }
}

private struct SleepTotals {
    var inBed = 0.0
    var asleep = 0.0
    var rem = 0.0
    var deep = 0.0
    var core = 0.0
    var awake = 0.0
}

extension HKWorkoutActivityType {
    /// Stable lowercase names, so `list_recent_workouts(type:)` filters on
    /// something an agent can guess.
    var slug: String {
        switch self {
        case .running: "running"
        case .walking: "walking"
        case .cycling: "cycling"
        case .hiking: "hiking"
        case .swimming: "swimming"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "strength"
        case .highIntensityIntervalTraining: "hiit"
        case .yoga: "yoga"
        case .rowing: "rowing"
        case .elliptical: "elliptical"
        case .stairClimbing: "stair_climbing"
        case .coreTraining: "core_training"
        case .pilates: "pilates"
        case .dance: "dance"
        case .soccer: "soccer"
        case .tennis: "tennis"
        case .basketball: "basketball"
        case .climbing: "climbing"
        case .downhillSkiing: "downhill_skiing"
        case .snowboarding: "snowboarding"
        case .crossCountrySkiing: "cross_country_skiing"
        default: "other"
        }
    }
}
