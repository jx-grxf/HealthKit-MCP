import AuthenticationServices
import SwiftUI

/// Sign in, or show who is signed in.
struct AccountPanel: View {
    @Environment(AccountStore.self) private var account
    @Environment(SyncStatus.self) private var status
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.caption)
                .foregroundStyle(.secondary)

            if account.isSignedIn {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(.tint)
                    Text(account.email ?? "Apple Account")
                        .font(.subheadline)
                    Spacer()
                }
                Button("Sign out", role: .destructive) {
                    Task {
                        await account.signOut()
                        status.restore(isSignedIn: false)
                    }
                }
                .font(.subheadline)
            } else {
                SignInWithAppleButton(.signIn) { request in
                    account.prepare(request)
                } onCompletion: { result in
                    Task {
                        await account.complete(result)
                        status.restore(isSignedIn: account.isSignedIn)
                    }
                }
                // Apple's own asset: black on light, white on dark. Pinned to
                // .black it vanished against a dark background.
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 48)
            }

            if let error = account.lastError {
                Text(error).font(.footnote).foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
