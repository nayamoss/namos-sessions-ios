import Foundation

/// Keeps the APNs token available across the short gap between app launch and Clerk
/// restoring a session. The backend associates this device with whichever signed-in user
/// registers it, so sign-out clears the in-memory registration marker before another
/// account can use the same installation.
@MainActor
final class DeviceTokenManager {
    static let shared = DeviceTokenManager()

    private let tokenDefaultsKey = "apnsDeviceToken"
    private var deviceToken: String?
    private var registeredToken: String?

    private init() {
        deviceToken = UserDefaults.standard.string(forKey: tokenDefaultsKey)
    }

    /// Stores the latest APNs token first, then registers it immediately when Clerk has
    /// already restored a session. Otherwise `registerIfPossible()` runs after sign-in.
    func received(deviceToken: Data) async {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        registeredToken = nil
        UserDefaults.standard.set(token, forKey: tokenDefaultsKey)
        await registerIfPossible()
    }

    /// Retries a token delivered before authentication, and also covers a cached token on
    /// a later app launch where APNs has not issued a new token yet.
    func registerIfPossible() async {
        guard ClerkAuthManager.shared.isSignedIn,
              let deviceToken,
              registeredToken != deviceToken else { return }
        do {
            let _: EmptyResult = try await ConvexClient.shared.mutation("deviceTokens:register", args: [
                "token": deviceToken,
                "platform": "ios",
            ])
            registeredToken = deviceToken
        } catch {
            print("[APNs] Device-token registration error: \(error.localizedDescription)")
        }
    }

    /// Runs while the Clerk session is still valid. A failed request is intentionally
    /// non-blocking: the device is marked unregistered locally before sign-out completes.
    func unregister() async {
        guard ClerkAuthManager.shared.isSignedIn,
              let deviceToken else {
            registeredToken = nil
            return
        }
        defer { registeredToken = nil }
        do {
            let _: EmptyResult = try await ConvexClient.shared.mutation("deviceTokens:unregister", args: [
                "token": deviceToken,
            ])
        } catch {
            print("[APNs] Device-token unregistration error: \(error.localizedDescription)")
        }
    }
}

/// Convex mutations that return `null` decode into a small empty value rather than Void.
private struct EmptyResult: Decodable {}
