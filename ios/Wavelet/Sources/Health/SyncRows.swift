import Foundation

/// Rows written to Supabase. Field names match the column names exactly.

struct MetricSettingRow: Encodable, Sendable {
    let user_id: String
    let metric_key: String
    let enabled: Bool
    let consented_at: String?
}

struct MetricDayRow: Encodable, Sendable {
    let user_id: String
    let date: String
    let metric_key: String
    let unit: String
    let value_sum: Double?
    let value_avg: Double?
    let value_min: Double?
    let value_max: Double?
    let value_latest: Double?
    let duration_minutes: Double?
    let sample_count: Int
}

struct SleepNightRow: Encodable, Sendable {
    let user_id: String
    let date: String
    let in_bed_minutes: Int?
    let asleep_minutes: Int?
    let rem_minutes: Int?
    let deep_minutes: Int?
    let core_minutes: Int?
    let awake_minutes: Int?
}

struct WorkoutRow: Encodable, Sendable {
    let id: String
    let user_id: String
    let type: String
    let start_at: String
    let end_at: String
    let duration_seconds: Int
    let distance_meters: Int?
    let active_energy_kcal: Int?
    let avg_hr_bpm: Int?
    let source: String?
}

struct ProfileRow: Encodable, Sendable {
    let id: String
    let agent_sharing_consent_at: String?
}

enum SyncFormat {
    /// Dates are keys in the database, so they must be formatted in the user's
    /// own timezone — a UTC date would put late-evening samples on the wrong day.
    static let day: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let timestamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
