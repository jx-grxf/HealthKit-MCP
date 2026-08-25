import Foundation

/// Append-only breadcrumb trail for the sync, written to Documents/sync.log.
///
/// A crash takes the in-memory state with it, so the last line written is the
/// last step that completed. Temporary diagnostic.
enum SyncLog {
    private static var url: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("sync.log")
    }

    static func reset() {
        guard let url else { return }
        try? "".write(to: url, atomically: true, encoding: .utf8)
    }

    static func note(_ message: String) {
        guard let url else { return }
        let line = "\(Date().timeIntervalSince1970) \(message)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
