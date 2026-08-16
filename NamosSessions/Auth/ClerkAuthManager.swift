import Foundation
import ClerkKit
import Observation

/// Bridges the @Observable `Clerk.shared` singleton into an ObservableObject
/// so existing SwiftUI code can keep using @EnvironmentObject.
/// Inject as an @EnvironmentObject from NamosSessionsApp.
/// Ported from the Sentio iOS app's ClerkAuthManager — same Clerk publishable-key
/// bootstrap pattern, same "convex" JWT template Clerk issues for Convex auth.
///
/// `Clerk.shared` asserts (crashes) if accessed before `Clerk.configure(publishableKey:)`
/// succeeds, so every touch of `Clerk.shared` in this class is gated behind `isConfigured`.
@MainActor
class ClerkAuthManager: ObservableObject {
    static let shared = ClerkAuthManager()

    @Published var isSignedIn: Bool = false
    @Published var userEmail: String?
    @Published var userFullName: String?
    @Published var userInitials: String = ""

    /// True once Clerk has been configured with a syntactically valid publishable key.
    private(set) var isConfigured = false

    /// Set when configuration was skipped because the key was missing or malformed —
    /// surfaced by SignInPlaceholderView so a bad build setting fails visibly instead of
    /// crashing. `Clerk.configure()` itself only asserts on a bad key (Debug-only crash,
    /// silently ignored in Release) — this check has to happen before calling it at all.
    private(set) var configurationError: String?

    private init() {
        configure()
    }

    // MARK: - Public

    func signOut() async {
        guard isConfigured else { return }
        await DeviceTokenManager.shared.unregister()
        do {
            try await Clerk.shared.auth.signOut()
        } catch {
            print("[ClerkAuth] Sign-out error: \(error.localizedDescription)")
        }
    }

    /// Convex's own auth check (`ctx.auth.getUserIdentity()` in every gated query/mutation)
    /// verifies against `CLERK_JWT_ISSUER_DOMAIN`, which the webapp already points at the
    /// Clerk JWT template literally named "convex" — see convex/auth.config.ts. Requesting
    /// the same template here means the iOS app authenticates against the identical
    /// organizer/reviewer rows the webapp uses; there is no separate mobile auth to build.
    func convexAuthToken() async throws -> String? {
        guard isConfigured else { return nil }
        let options = Session.GetTokenOptions(template: "convex")
        return try await Clerk.shared.session?.getToken(options)
    }

    // MARK: - Private

    private func configure() {
        // Only an empty-string check is safe to do ourselves: ClerkKit's real validation
        // base64-decodes whatever follows "pk_test_"/"pk_live_" to derive its API URL, and
        // that step can crash (assertionFailure, Debug-only) on a well-prefixed-but-fake
        // key. There's no ClerkKit API to pre-validate that without duplicating internals
        // that could drift — so Config.xcconfig.example ships the key blank on purpose.
        guard let key = Bundle.main.object(forInfoDictionaryKey: "ClerkPublishableKey") as? String,
              !key.isEmpty else {
            configurationError = "ClerkPublishableKey is missing. Set CLERK_PUBLISHABLE_KEY in Config.local.xcconfig to your project's real pk_test_/pk_live_ key."
            print("⚠️ \(configurationError!)")
            return
        }
        Clerk.configure(publishableKey: key)
        isConfigured = true
        updateState()
        observeClerk()
    }

    /// Re-subscribes to Clerk's Observation-tracked properties after every change,
    /// since `withObservationTracking` fires its `onChange` callback only once.
    private func observeClerk() {
        withObservationTracking {
            _ = Clerk.shared.user
            _ = Clerk.shared.session
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateState()
                self?.observeClerk()
            }
        }
    }

    private func updateState() {
        guard isConfigured else { return }
        let user = Clerk.shared.user
        isSignedIn = Clerk.shared.session != nil
        userEmail = user?.primaryEmailAddress?.emailAddress

        let fullName = [user?.firstName, user?.lastName].compactMap { $0 }.joined(separator: " ")
        userFullName = fullName.isEmpty ? nil : fullName

        if let name = userFullName, !name.isEmpty {
            let parts = name.split(separator: " ")
            userInitials = parts.compactMap { $0.first }.prefix(2).map(String.init).joined()
        } else if let email = userEmail {
            userInitials = String(email.prefix(1)).uppercased()
        } else {
            userInitials = "?"
        }
    }
}
