import ClerkConvex
import ConvexMobile
import Foundation

/// Keeps Convex's official WebSocket client alive for the process. ClerkConvexAuthProvider
/// follows the same Clerk session as our HTTP fallback, but supplies updates as subscriptions.
@MainActor
final class ConvexLiveClient {
    static let shared = ConvexLiveClient()

    let client: ConvexClientWithAuth<String>?

    private init() {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "ConvexBaseURL") as? String,
              !raw.isEmpty else {
            client = nil
            print("⚠️ ConvexBaseURL missing or empty — live subscriptions are unavailable.")
            return
        }
        client = ConvexClientWithAuth(
            deploymentUrl: raw,
            authProvider: ClerkConvexAuthProvider()
        )
    }
}
