import Foundation
import Observation
import Supabase

/// One recorded read by an assistant.
struct AccessEntry: Decodable, Identifiable, Sendable {
    let id: Int
    let tool: String
    let client: String?
    let at: Date

    private enum CodingKeys: String, CodingKey { case id, tool, client, at }
}

/// The user's own audit trail.
///
/// Read under RLS as the signed-in user, so this shows exactly what the server
/// recorded against their account and nothing else.
@Observable
@MainActor
final class AccessLogStore {
    private(set) var entries: [AccessEntry] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    var totalReads: Int { entries.count }

    var readsToday: Int {
        let start = Calendar.current.startOfDay(for: Date())
        return entries.count { $0.at >= start }
    }

    var lastRead: Date? { entries.first?.at }

    /// Distinct assistants that have read anything, newest first.
    var clients: [String] {
        var seen: [String] = []
        for entry in entries {
            let name = entry.client ?? "Unknown"
            if !seen.contains(name) { seen.append(name) }
        }
        return seen
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            entries = try await Backend.client
                .from("mcp_access_log")
                .select("id,tool,client,at")
                .order("at", ascending: false)
                .limit(200)
                .execute()
                .value
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
