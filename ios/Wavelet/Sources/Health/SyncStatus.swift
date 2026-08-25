import Foundation
import Observation

/// Truthful state of the summary upload.
///
/// It reports `.notConfigured` until an account exists, rather than pretending
/// to be idle. A sync indicator that looks healthy while nothing is syncing is
/// worse than no indicator at all — the user would believe their assistants
/// have current data when they do not.
enum SyncState: Sendable, Equatable {
    case notConfigured
    case idle(lastSync: Date?)
    case syncing
    case failed(String)
}

@Observable
@MainActor
final class SyncStatus {
    private(set) var state: SyncState = .notConfigured
    /// Rows written by the last successful sync, for an honest "it did something".
    var lastRowCount: Int = 0

    func set(_ next: SyncState) { state = next }

    var isSyncing: Bool { if case .syncing = state { true } else { false } }

    /// Whether HealthKit authorization has been requested at least once.
    /// iOS never discloses whether read access was *granted*, so this is
    /// deliberately "requested", not "granted".
    var hasRequestedHealthAccess: Bool {
        didSet {
            UserDefaults.standard.set(
                hasRequestedHealthAccess, forKey: "wavelet.healthRequested.v1")
        }
    }

    init() {
        hasRequestedHealthAccess =
            UserDefaults.standard.bool(forKey: "wavelet.healthRequested.v1")
    }

    var title: String {
        switch state {
        case .notConfigured: String(localized: "Not connected")
        case .idle(nil): String(localized: "Never synced")
        case .idle: String(localized: "Last synced")
        case .syncing: String(localized: "Syncing…")
        case .failed: String(localized: "Sync failed")
        }
    }

    var detail: String {
        switch state {
        case .notConfigured:
            String(localized: "Sign in to start syncing your summaries.")
        case .idle(let date):
            date.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? ""
        case .syncing:
            ""
        case .failed(let message):
            message
        }
    }

    var symbol: String {
        switch state {
        case .notConfigured: "person.crop.circle.badge.exclamationmark"
        case .idle(nil): "arrow.triangle.2.circlepath"
        case .idle: "checkmark.circle.fill"
        case .syncing: "arrow.triangle.2.circlepath"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color2 {
        switch state {
        case .notConfigured, .idle(nil): .secondary
        case .idle: .good
        case .syncing: .secondary
        case .failed: .bad
        }
    }

    /// Small indirection so this model stays free of SwiftUI.
    enum Color2 { case secondary, good, bad }
}
