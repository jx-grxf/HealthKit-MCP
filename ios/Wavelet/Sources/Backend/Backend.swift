import Foundation
import Supabase

/// Shared Supabase client.
///
/// Uses the publishable key only — never the service-role key, which bypasses
/// Row-Level Security and belongs on the server. Everything this app reads or
/// writes goes through RLS as the signed-in user.
enum Backend {
    static let projectURL = URL(string: "https://xwmtuzkosztpxjyhvjch.supabase.co")!
    static let publishableKey = "sb_publishable_mV8MzD3h2waFMZ_Oc7ZFNQ_asDSRn6i"

    static let client = SupabaseClient(
        supabaseURL: projectURL,
        supabaseKey: publishableKey,
    )
}
