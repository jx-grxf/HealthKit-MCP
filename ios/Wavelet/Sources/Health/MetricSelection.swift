import Foundation
import Observation

/// Which metrics the user shares, and when they consented to each.
///
/// Persisted locally for now; Phase 1 mirrors this into Supabase's
/// `user_metric_settings`, which is what actually gates agent reads. Nothing
/// here is a security boundary — the database join is. This only decides what
/// the app reads from HealthKit in the first place, which is the *other* half
/// of data minimisation: a metric that is off is never read at all.
@Observable
@MainActor
final class MetricSelection {
    private static let storageKey = "wavelet.enabledMetrics.v1"

    /// metric key → consent timestamp.
    private(set) var consented: [String: Date] = [:]

    /// True once the user has accepted the third-party AI sharing disclosure.
    var hasAcceptedSharingDisclosure: Bool {
        didSet {
            UserDefaults.standard.set(
                hasAcceptedSharingDisclosure, forKey: "wavelet.sharingDisclosure.v1")
        }
    }

    init() {
        hasAcceptedSharingDisclosure =
            UserDefaults.standard.bool(forKey: "wavelet.sharingDisclosure.v1")
        if let raw = UserDefaults.standard.dictionary(forKey: Self.storageKey)
            as? [String: Double]
        {
            consented = raw.mapValues { Date(timeIntervalSince1970: $0) }
        }
    }

    func isEnabled(_ metric: MetricDescriptor) -> Bool {
        consented[metric.key] != nil
    }

    var enabledMetrics: [MetricDescriptor] {
        consented.keys.compactMap { MetricCatalog.byKey[$0] }.sorted { $0.name < $1.name }
    }

    var enabledCount: Int { consented.count }

    func enabledCount(in category: MetricCategory) -> Int {
        MetricCatalog.inCategory(category).count { consented[$0.key] != nil }
    }

    func setEnabled(_ enabled: Bool, for metric: MetricDescriptor) {
        if enabled {
            consented[metric.key] = Date()
        } else {
            consented.removeValue(forKey: metric.key)
        }
        persist()
    }

    /// Bulk-enable a category. Sensitive metrics are deliberately excluded:
    /// reproductive-health and symptom data must be switched on one at a time.
    func enableAll(in category: MetricCategory) {
        for metric in MetricCatalog.inCategory(category)
        where metric.sensitivity == .standard && consented[metric.key] == nil {
            consented[metric.key] = Date()
        }
        persist()
    }

    func disableAll(in category: MetricCategory) {
        for metric in MetricCatalog.inCategory(category) {
            consented.removeValue(forKey: metric.key)
        }
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(
            consented.mapValues(\.timeIntervalSince1970), forKey: Self.storageKey)
    }
}
