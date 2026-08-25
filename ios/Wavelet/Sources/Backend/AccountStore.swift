import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Supabase

/// Sign in with Apple, natively.
///
/// The native flow hands us an identity token directly, so there is no browser
/// redirect and no client secret to rotate — unlike the web flow the consent
/// screen uses. Supabase verifies the token against Apple's keys.
@Observable
@MainActor
final class AccountStore {
    private(set) var userId: UUID?
    private(set) var email: String?
    private(set) var isWorking = false
    private(set) var lastError: String?

    var isSignedIn: Bool { userId != nil }

    /// Raw nonce for the in-flight request. Apple receives its SHA-256; Supabase
    /// receives the raw value and checks they match, which is what stops a
    /// captured identity token being replayed.
    private var currentNonce: String?

    func restoreSession() async {
        do {
            let session = try await Backend.client.auth.session
            apply(session.user)
        } catch {
            userId = nil
            email = nil
        }
    }

    /// Configures the Apple authorization request. Call from `onRequest`.
    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.email]
        request.nonce = Self.sha256(nonce)
    }

    /// Completes sign-in. Call from `onCompletion`.
    func complete(_ result: Result<ASAuthorization, Error>) async {
        isWorking = true
        defer { isWorking = false }

        switch result {
        case .failure(let error):
            // The user cancelling is not an error worth showing.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            lastError = error.localizedDescription

        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                lastError = "Apple did not return an identity token."
                return
            }

            do {
                let session = try await Backend.client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken, nonce: nonce),
                )
                apply(session.user)
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
            currentNonce = nil
        }
    }

    func signOut() async {
        try? await Backend.client.auth.signOut()
        userId = nil
        email = nil
    }

    private func apply(_ user: User) {
        userId = user.id
        email = user.email
    }

    // MARK: - Nonce

    private static func randomNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        precondition(status == errSecSuccess, "Unable to generate a secure nonce.")
        // Unreserved URL characters only, so the value survives the round trip.
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
