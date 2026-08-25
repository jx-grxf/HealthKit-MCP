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
    /// How far back a manual sync reaches.
    static let windowDays = 30

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
        do {
            try await upsertProfile(userId: userId, selection: selection)
            try await upsertSettings(userId: userId, selection: selection)

            let enabled = selection.enabledMetrics
            // Asking for read authorization again is cheap and covers metrics
            // switched on since the last prompt.
            try await store.requestAuthorization(
                toShare: [], read: Set(enabled.compactMap(\.objectType)))

            var rows: [MetricDayRow] = []
            for metric in enabled where metric.kind == .quantity {
                rows += try await dailyStatistics(for: metric, userId: userId)
            }
            if !rows.isEmpty {
                try await Backend.client
                    .from("health_metric_days")
                    .upsert(rows, onConflict: "user_id,date,metric_key")
                    .execute()
            }

            status.set(.idle(lastSync: Date()))
            status.lastRowCount = rows.count
        } catch {
            status.set(.failed(error.localizedDescription))
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
        else { return [] }

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
            query.initialResultsHandler = { _, collection, error in
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
                        ))
                }
                continuation.resume(returning: out)
            }
            store.execute(query)
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
                value_sum: bucket.sum,
                value_avg: bucket.avg,
                value_min: bucket.min,
                value_max: bucket.max,
                value_latest: bucket.latest,
                duration_minutes: nil,
                sample_count: 1,
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

    var hasValue: Bool {
        sum != nil || avg != nil || min != nil || max != nil || latest != nil
    }
}
