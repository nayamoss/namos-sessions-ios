import ConvexMobile
import Foundation

/// Keeps Convex's official WebSocket client alive for the process. ClerkConvexAuthProvider
/// follows the same Clerk session as our HTTP fallback, but supplies updates as subscriptions.
@MainActor
final class ConvexLiveClient {
    static let shared = ConvexLiveClient()

    let client: ConvexClientWithAuth<String>?
    private let authProvider = ConvexTemplateAuthProvider()

    private init() {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "ConvexBaseURL") as? String,
              !raw.isEmpty else {
            client = nil
            print("⚠️ ConvexBaseURL missing or empty — live subscriptions are unavailable.")
            return
        }
        client = ConvexClientWithAuth(
            deploymentUrl: raw,
            authProvider: authProvider
        )
    }

    /// Hands the cached Clerk session to Convex.
    ///
    /// `ConvexClientWithAuth` opens its WebSocket unauthenticated and stays that way
    /// until something calls `login()`/`loginFromCache()`. Nothing did. Every
    /// event-scoped query is behind `assertEventOrganizerAccess`, so the server
    /// rejected each subscription and the socket sat in a reconnect loop — which is
    /// why the Dashboard, Tasks, Agenda, Speakers, Sponsors, Check-in, Notifications
    /// and Agent screens all showed their initial zero/empty values forever. The
    /// screens that appeared to work were the ones on the HTTP path in ConvexClient,
    /// which attaches the Clerk JWT per request and was never affected.
    ///
    /// Safe to call repeatedly; each call just re-reads the cached session.
    @discardableResult
    func authenticate() async -> Bool {
        guard let client else { return false }
        switch await client.loginFromCache() {
        case .success:
            print("✅ Convex live client authenticated with the Clerk 'convex' template.")
            return true
        case .failure(let error):
            print("⚠️ Convex live login failed — live subscriptions will not deliver: \(String(reflecting: error))")
            return false
        }
    }

    func logout() async {
        await client?.logout()
    }
}
