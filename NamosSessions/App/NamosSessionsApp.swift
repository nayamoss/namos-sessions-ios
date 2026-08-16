import SwiftUI

@main
struct NamosSessionsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("appearancePreference") private var appearancePreference = 0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    private var preferredColorScheme: ColorScheme? {
        switch appearancePreference {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    init() {
        // Triggers ClerkAuthManager's lazy singleton init, which calls
        // Clerk.configure(publishableKey:) — same bootstrap Sentio's iOS app uses.
        _ = ClerkAuthManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ClerkAuthManager.shared)
                .preferredColorScheme(preferredColorScheme)
                .task {
                    guard notificationsEnabled else { return }
                    await DeviceTokenManager.shared.registerIfPossible()
                }
                .onChange(of: ClerkAuthManager.shared.isSignedIn) { _, isSignedIn in
                    guard isSignedIn, notificationsEnabled else { return }
                    Task {
                        await DeviceTokenManager.shared.registerIfPossible()
                    }
                }
        }
    }
}
