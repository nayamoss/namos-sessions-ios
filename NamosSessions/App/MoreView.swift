import SwiftUI

struct MoreView: View {
    let eventId: ConvexId
    let eventName: String
    @ObservedObject var notifications: NotificationsViewModel
    let reviewerName: String

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                NavigationLink(value: MoreDestination.checkIn) {
                    MoreRow(title: "Check-in", systemImage: "person.crop.circle.badge.checkmark")
                }
                NavigationLink(value: MoreDestination.speakers) {
                    MoreRow(title: "Speakers", systemImage: "person.2")
                }
                NavigationLink(value: MoreDestination.reviews) {
                    MoreRow(title: "Reviews", systemImage: "checklist")
                }
                NavigationLink(value: MoreDestination.sponsors) {
                    MoreRow(title: "Sponsors", systemImage: "building.2")
                }
                NavigationLink(value: MoreDestination.notifications) {
                    MoreRow(
                        title: "Notifications",
                        systemImage: "bell",
                        badge: notifications.unreadCount == 0 ? nil : "\(notifications.unreadCount)"
                    )
                }

                NavigationLink(value: MoreDestination.settings) {
                    MoreRow(title: "Settings", systemImage: "gearshape")
                }
                .padding(.top, 14)
            }
            .padding(16)
        }
        .background(NamosColor.background)
        .navigationTitle("More")
        .navigationDestination(for: MoreDestination.self) { destination in
            destinationView(for: destination)
        }
    }

    @ViewBuilder
    private func destinationView(for destination: MoreDestination) -> some View {
        switch destination {
        case .checkIn:
            CheckInView(eventId: eventId)
        case .speakers:
            SpeakersView(eventId: eventId)
        case .reviews:
            ReviewsHubView(eventId: eventId, reviewerName: reviewerName)
        case .sponsors:
            SponsorsView(eventId: eventId)
        case .notifications:
            NotificationsView(viewModel: notifications)
        case .settings:
            SettingsView(eventName: eventName)
        }
    }
}

private struct MoreRow: View {
    let title: String
    let systemImage: String
    var badge: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(NamosColor.accent)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(NamosColor.text)

            Spacer()

            if let badge {
                Text(badge)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NamosColor.background)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(NamosColor.accent)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NamosColor.mutedText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NamosColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
