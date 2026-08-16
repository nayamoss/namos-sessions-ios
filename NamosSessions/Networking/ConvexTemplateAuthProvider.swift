import ClerkKit
import ConvexMobile
import Foundation

/// Authenticates the live Convex client with the same Clerk JWT template as the
/// HTTP client. The generic ClerkConvex adapter requests Clerk's default token,
/// but this backend is configured to trust the explicitly named `convex` template.
@MainActor
final class ConvexTemplateAuthProvider: AuthProvider {
    typealias T = String

    private var onIdToken: (@Sendable (String?) -> Void)?

    func login(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> String {
        self.onIdToken = onIdToken
        return try await convexToken()
    }

    func loginFromCache(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> String {
        self.onIdToken = onIdToken
        return try await convexToken()
    }

    func logout() async throws {
        onIdToken?(nil)
        onIdToken = nil
    }

    nonisolated func extractIdToken(from authResult: String) -> String {
        authResult
    }

    private func convexToken() async throws -> String {
        guard let token = try await ClerkAuthManager.shared.convexAuthToken(), !token.isEmpty else {
            throw ConvexTemplateAuthError.missingToken
        }
        return token
    }
}

private enum ConvexTemplateAuthError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        "Couldn't retrieve the Clerk Convex token for live updates."
    }
}
