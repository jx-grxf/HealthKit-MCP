import Foundation
import HealthKit
import Observation
import Supabase

/// Reads the enabled HealthKit types, rolls them up per day on device, and
/// upserts the summaries.
///
/// Individual samples never leave the phone: only the daily statistics do. The
/// window is re-read and upserted wholesale rather than tracked with anchors —
/// simple and idempotent, at the cost of re-sending a month of rows. Anchored
/// incremental sync is the next step, not a correctness fix.
@Observable
@MainActor
final class HealthSync {
    /// How far back a sync reaches. A year, because an agent asked for four
    /// months of history and could only be given four weeks.
    static let windowDays = 365

    /// Supabase rejects very large payloads, and a year across ~120 metrics is
    /// tens of thousands of rows, so upserts go up in batches.
    static let batchSize = 500

    private let store = HKHealthStore()

    func run(
        selection: MetricSelection,
        account: AccountStore,
        status: SyncStatus,
    ) async {
        guard let userId = account.userId?.uuidString else {
            status.set(.notConfigured)
            return
        }
        guard HKHealthStore.isHealthDataAvailable() else {
            status.set(.failed("Health data isn't available on this device."))
            return
        }

        status.set(.syncing)
        SyncLog.reset()
        SyncLog.note("start user=\(userId) enabled=\(selection.enabledCount)")
        do {
            try await upsertProfile(userId: userId, selection: selection)
            SyncLog.note("profile ok")
            try await upsertSettings(userId: userId, selection: selection)
            SyncLog.note("settings ok")

            let enabled = selection.enabledMetrics
            // Asking for read authorization again is cheap and covers metrics
            // switched on since the last prompt.
            try await store.requestAuthorization(
                toShare: [], read: Set(enabled.compactMap(\.objectType)))
            SyncLog.note("authorization ok, quantity metrics=\(enabled.filter { $0.kind == .quantity }.count)")

            var rows: [MetricDayRow] = []
            for metric in enabled where metric.kind == .quantity {
                SyncLog.note("query \(metric.key)")
                if metric.key == "dietary_water" {
                    SyncLog.note("water unit=\(metric.unit ?? "nil") hk=\(MetricUnits.hkUnit(for: metric.unit)?.unitString ?? "nil")")
                }
                rows += try await dailyStatistics(for: metric, userId: userId)
            }
            SyncLog.note("quantity done rows=\(rows.count)")

            // Categories and workouts: HealthKit has no statistics collection
            // for these, so the samples are fetched and folded by hand.
            let calendar = Calendar.current
            let end = Date()
            let start = calendar.date(byAdding: .day, value: -Self.windowDays, to: end) ?? end

            var sleepRows: [SleepNightRow] = []
            for metric in enabled where metric.kind == .category {
                guard let type = metric.objectType as? HKSampleType else { continue }
                SyncLog.note("category \(metric.key)")
                let samples = try await CategorySync.fetchSamples(
                    store: store, type: type, start: start, end: end)
                if metric.key == "sleep_analysis" {
                    let (nights, days) = CategorySync.sleepNights(
                        from: samples, userId: userId, calendar: calendar)
                    sleepRows += nights
                    rows += days
                } else {
                    rows += CategorySync.categoryDays(
                        from: samples, metric: metric, userId: userId, calendar: calendar)
                }
            }
            if !sleepRows.isEmpty {
                try await Backend.client
                    .from("sleep_nights")
                    .upsert(sleepRows, onConflict: "user_id,date")
                    .execute()
                SyncLog.note("sleep nights=\(sleepRows.count)")
            }

            if enabled.contains(where: { $0.kind == .workout }) {
                let samples = try await CategorySync.fetchSamples(
                    store: store, type: HKObjectType.workoutType(), start: start, end: end)
                let workouts = CategorySync.workoutRows(from: samples, userId: userId)
                if !workouts.isEmpty {
                    for start in stride(from: 0, to: workouts.count, by: Self.batchSize) {
                        let batch = Array(workouts[start ..< min(start + Self.batchSize, workouts.count)])
                        try await Backend.client
                            .from("workouts")
                            .upsert(batch, onConflict: "user_id,id")
                            .execute()
                    }
                    rows += CategorySync.workoutDays(
                        from: workouts, userId: userId, calendar: calendar)
                }
                SyncLog.note("workouts=\(workouts.count)")
            }
            try await upsertMetricDays(rows)
            SyncLog.note("upsert ok rows=\(rows.count)")

            status.recordSync(at: Date())
            status.lastRowCount = rows.count
        } catch {
            SyncLog.note("ERROR \(error)")
            status.set(.failed(error.localizedDescription))
        }
    }

    private func upsertMetricDays(_ rows: [MetricDayRow]) async throws {
        guard !rows.isEmpty else { return }
        for start in stride(from: 0, to: rows.count, by: Self.batchSize) {
            let batch = Array(rows[start ..< min(start + Self.batchSize, rows.count)])
            try await Backend.client
                .from("health_metric_days")
                .upsert(batch, onConflict: "user_id,date,metric_key")
                .execute()
            SyncLog.note("batch \(start / Self.batchSize + 1) rows=\(batch.count)")
        }
    }

    // MARK: - Supabase writes

    private func upsertProfile(userId: String, selection: MetricSelection) async throws {
        let row = ProfileRow(
            id: userId,
            agent_sharing_consent_at: selection.hasAcceptedSharingDisclosure
                ? SyncFormat.timestamp.string(from: Date()) : nil,
        )
        try await Backend.client.from("profiles").upsert(row, onConflict: "id").execute()
    }

    /// Writes the full switch state, not just what is on, so that turning a
    /// metric off is recorded as `enabled = false` and the consent join stops
    /// matching it.
    private func upsertSettings(userId: String, selection: MetricSelection) async throws {
        let rows = MetricCatalog.available.map { metric in
            MetricSettingRow(
                user_id: userId,
                metric_key: metric.key,
                enabled: selection.isEnabled(metric),
                consented_at: selection.consentedAt(metric)
                    .map(SyncFormat.timestamp.string(from:)),
            )
        }
        try await Backend.client
            .from("user_metric_settings")
            .upsert(rows, onConflict: "user_id,metric_key")
            .execute()
    }

    // MARK: - HealthKit

    private func dailyStatistics(
        for metric: MetricDescriptor,
        userId: String,
    ) async throws -> [MetricDayRow] {
        guard
            let quantityType = metric.objectType as? HKQuantityType,
            let unit = MetricUnits.hkUnit(for: metric.unit),
            let options = MetricUnits.statisticsOptions(for: metric.aggregation)
        else {
            SyncLog.note("skip \(metric.key): no unit or options")
            return []
        }

        // The catalog's unit is derived from the SQL seed, not from HealthKit, so
        // it can disagree with what a type actually measures — Apple's effort
        // scores use their own unit, for one. Converting with an incompatible
        // unit raises an Objective-C exception that Swift cannot catch, which
        // takes the whole app down. Ask HealthKit first and skip instead.
        guard quantityType.is(compatibleWith: unit) else {
            SyncLog.note("skip \(metric.key): unit \(metric.unit ?? "nil") incompatible")
            return []
        }

        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        guard
            let start = calendar.date(byAdding: .day, value: -Self.windowDays, to: end),
            let anchor = calendar.date(byAdding: .day, value: 1, to: end)
        else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: Date(), options: .strictStartDate)

        let buckets: [StatBucket] = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchor,
                intervalComponents: DateComponents(day: 1),
            )
            query.initialResultsHandler = { [store] executed, collection, error in
                // Without this the query stays live waiting for updates. One per
                // enabled metric means well over a hundred running at once.
                store.stop(executed)
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let collection else {
                    continuation.resume(returning: [])
                    return
                }
                // HKStatistics is not Sendable, so everything needed is read out
                // here and only plain values cross the boundary.
                var out: [StatBucket] = []
                collection.enumerateStatistics(from: start, to: end) { stats, _ in
                    out.append(
                        StatBucket(
                            day: stats.startDate,
                            sum: stats.sumQuantity()?.doubleValue(for: unit),
                            avg: stats.averageQuantity()?.doubleValue(for: unit),
                            min: stats.minimumQuantity()?.doubleValue(for: unit),
                            max: stats.maximumQuantity()?.doubleValue(for: unit),
                            latest: stats.mostRecentQuantity()?.doubleValue(for: unit),
                            // Which app or device wrote it. An agent can then
                            // judge whether a nutrition figure is complete, or
                            // spot a source writing implausible magnitudes.
                            sources: stats.sources?.map(\.name).sorted(),
                        ))
                }
                continuation.resume(returning: out)
            }
            store.execute(query)
        }

        let scale = MetricUnits.scale(for: metric.unit)
        let whole = MetricUnits.isWholeNumber(metric.unit)
        func adjust(_ value: Double?) -> Double? {
            guard let value else { return nil }
            let scaled = value * scale
            return whole ? scaled.rounded() : scaled
        }

        return buckets.compactMap { bucket in
            // A day with no samples yields all-nil; writing those would invent
            // rows the user has no data for.
            guard bucket.hasValue else { return nil }
            return MetricDayRow(
                user_id: userId,
                date: SyncFormat.day.string(from: bucket.day),
                metric_key: metric.key,
                unit: metric.unit ?? "count",
                value_sum: adjust(bucket.sum),
                value_avg: adjust(bucket.avg),
                value_min: adjust(bucket.min),
                value_max: adjust(bucket.max),
                value_latest: adjust(bucket.latest),
                duration_minutes: nil,
                // HealthKit statistics do not expose how many samples went into
                // them. Reporting 1 implied a single reading; null says unknown.
                sample_count: nil,
                sources: bucket.sources,
            )
        }
    }
}

/// Plain, Sendable snapshot of one day's statistics.
private struct StatBucket: Sendable {
    let day: Date
    let sum: Double?
    let avg: Double?
    let min: Double?
    let max: Double?
    let latest: Double?
    let sources: [String]?

    var hasValue: Bool {
        sum != nil || avg != nil || min != nil || max != nil || latest != nil
    }
}
