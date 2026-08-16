import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: ClerkAuthManager
    @AppStorage("appearancePreference") private var appearancePreference = 0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var isSignOutConfirmationPresented = false

    let eventName: String

    private var displayName: String {
        auth.userFullName ?? auth.userEmail ?? "Signed in"
    }

    private var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                accountSection
                appearanceSection
                notificationsSection
                aboutSection
            }
            .padding(16)
        }
        .background(NamosColor.background)
        .navigationTitle("Settings")
        .confirmationDialog("Sign out?", isPresented: $isSignOutConfirmationPresented, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task { await auth.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You’ll need to sign in again to access your events.")
        }
        .onChange(of: notificationsEnabled) { _, enabled in
            Task {
                if enabled {
                    await DeviceTokenManager.shared.registerIfPossible()
                } else {
                    await DeviceTokenManager.shared.unregister()
                }
            }
        }
    }

    private var accountSection: some View {
        SettingsSection(title: "Account") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Text(auth.userInitials)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NamosColor.accent)
                        .frame(width: 44, height: 44)
                        .background(NamosColor.background)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(NamosColor.text)
                        if auth.userFullName != nil, let email = auth.userEmail {
                            Text(email)
                                .font(.system(size: 13))
                                .foregroundStyle(NamosColor.mutedText)
                        }
                    }
                }

                Text(eventName)
                    .font(.system(size: 14))
                    .foregroundStyle(NamosColor.mutedText)

                Button("Sign Out") {
                    isSignOutConfirmationPresented = true
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(NamosColor.warning)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var appearanceSection: some View {
        SettingsSection(title: "Appearance") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose how Namos Sessions appears on this device.")
                    .font(.system(size: 13))
                    .foregroundStyle(NamosColor.mutedText)
                Picker("Appearance", selection: $appearancePreference) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(.segmented)
                .tint(NamosColor.accent)
            }
        }
    }

    private var notificationsSection: some View {
        SettingsSection(title: "Notifications") {
            Toggle("Enable notifications", isOn: $notificationsEnabled)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(NamosColor.text)
                .tint(NamosColor.accent)
        }
    }

    private var aboutSection: some View {
        SettingsSection(title: "About") {
            Text(versionDescription)
                .font(.system(size: 14))
                .foregroundStyle(NamosColor.mutedText)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NamosColor.text)
            content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NamosColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
