import AuthenticationServices
import SwiftUI

/// Account and sync controls.
///
/// Sync is only offered once signed in, because without an account there is
/// nowhere for the summaries to go — offering the button anyway would just
/// produce a failure the user cannot act on.
struct AccountSection: View {
    @Environment(AccountStore.self) private var account
    @Environment(MetricSelection.self) private var selection
    @Environment(SyncStatus.self) private var status
    @Environment(HealthSync.self) private var sync
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Section("Account") {
            if account.isSignedIn {
                LabeledContent("Signed in") {
                    Text(account.email ?? "Apple Account")
                        .foregroundStyle(.secondary)
                }
                Button("Sync now") {
                    Task { await sync.run(selection: selection, account: account, status: status) }
                }
                .disabled(selection.enabledCount == 0 || status.isSyncing)

                Button("Sign out", role: .destructive) {
                    Task { await account.signOut() }
                }
            } else {
                SignInWithAppleButton(.signIn) { request in
                    account.prepare(request)
                } onCompletion: { result in
                    Task { await account.complete(result) }
                }
                // Apple's own asset: black on light, white on dark. Fixed to
                // .black it disappears against a dark List background.
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 48)
                .padding(.vertical, 4)
            }

            if let error = account.lastError {
                Text(error).font(.footnote).foregroundStyle(.orange)
            }
        }
    }
}
