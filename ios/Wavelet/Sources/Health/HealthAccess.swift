import Foundation
import HealthKit

/// Thin wrapper over HealthKit authorization.
///
/// Read-only throughout: `toShare` is always empty, so iOS never offers the
/// user a write permission this app would not use.
@MainActor
final class HealthAccess {
    enum Failure: LocalizedError {
        case unavailable

        var errorDescription: String? {
            switch self {
            case .unavailable:
                "Health data isn't available on this device."
            }
        }
    }

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Requests read access for exactly the metrics the user switched on.
    ///
    /// iOS deliberately never reports read authorization status, so a
    /// successful return means "the user has been asked", not "access granted".
    /// Treat an empty query result as "denied or no data" and never as an error.
    func requestAuthorization(for metrics: [MetricDescriptor]) async throws {
        guard isAvailable else { throw Failure.unavailable }
        let types = Set(metrics.compactMap(\.objectType))
        guard !types.isEmpty else { return }
        try await store.requestAuthorization(toShare: [], read: types)
    }
}
