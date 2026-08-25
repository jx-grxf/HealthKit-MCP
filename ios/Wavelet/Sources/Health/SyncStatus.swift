import Foundation
import Observation

/// Truthful state of the summary upload.
///
/// Reports `.notConfigured` until an account exists rather than pretending to
/// be idle. An indicator that looks healthy while nothing is syncing is worse
/// than none: the user would believe their assistants have current data.
enum SyncState: Sendable, Equatable {
    case notConfigured
    case idle(lastSync: Date?)
    case syncing
    case failed(String)
}

@Observable
@MainActor
final class SyncStatus {
    private static let lastSyncKey = "wavelet.lastSync.v1"

    private(set) var state: SyncState = .notConfigured

    /// Rows written by the last successful sync, for an honest "it did something".
    var lastRowCount: Int = 0

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

    var isSyncing: Bool { if case .syncing = state { true } else { false } }

    func set(_ next: SyncState) { state = next }

    /// Restores the card after a cold launch.
    ///
    /// State used to start at `.notConfigured` and nothing ever corrected it,
    /// so a signed-in user who had already synced was told to sign in again on
    /// every launch.
    func restore(isSignedIn: Bool) {
        guard isSignedIn else {
            state = .notConfigured
            return
        }
        let stored = UserDefaults.standard.double(forKey: Self.lastSyncKey)
        state = .idle(lastSync: stored > 0 ? Date(timeIntervalSince1970: stored) : nil)
    }

    func recordSync(at date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: Self.lastSyncKey)
        state = .idle(lastSync: date)
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

    var tint: Tint {
        switch state {
        case .notConfigured, .idle(nil): .secondary
        case .idle: .good
        case .syncing: .secondary
        case .failed: .bad
        }
    }

    /// Small indirection so this model stays free of SwiftUI.
    enum Tint { case secondary, good, bad }
}
