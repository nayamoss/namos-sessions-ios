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
                // Blue is banned in this app, but toolbar buttons — unlike custom Button
                // views — take the system accent unless something overrides it, which is
                // how "Cancel"/"Create" on the New Task sheet ended up system blue.
                // Tinting at the scene root covers every sheet and toolbar at once
                // rather than relying on each new screen to remember.
                .tint(NamosColor.accent)
                .preferredColorScheme(preferredColorScheme)
                .task {
                    guard notificationsEnabled else { return }
                    await DeviceTokenManager.shared.registerIfPossible()
                }
                .onChange(of: ClerkAuthManager.shared.isSignedIn) { _, isSignedIn in
                    Task {
                        if isSignedIn {
                            _ = await ConvexLiveClient.shared.authenticate()
                            guard notificationsEnabled else { return }
                            await DeviceTokenManager.shared.registerIfPossible()
                        } else {
                            await ConvexLiveClient.shared.logout()
                        }
                    }
                }
        }
    }
}
