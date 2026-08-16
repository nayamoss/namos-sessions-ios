import Combine
import SwiftUI

/// The small shared navigation surface used by workflows that need to leave their
/// current tab, including the hands-free voice agent.
enum AppTab: Hashable {
    case dashboard
    case agent
    case tasks
    case agenda
    case more

    // These destinations remain part of the shared navigation vocabulary even though
    // they now live inside More rather than directly in the tab bar.
    case checkIn
    case speakers
    case notifications
    case reviews
    case sponsors
}

enum MoreDestination: Hashable {
    case checkIn
    case speakers
    case reviews
    case sponsors
    case notifications
    case settings
}

@MainActor
final class AppNavigationState: ObservableObject {
    @Published var selectedTab: AppTab = .dashboard
    @Published var morePath: [MoreDestination] = []

    func showMore(_ destination: MoreDestination) {
        morePath = [destination]
        selectedTab = .more
    }
}

struct ContentView: View {
    @EnvironmentObject var auth: ClerkAuthManager

    var body: some View {
        if auth.isSignedIn {
            EventScopedTabView()
        } else if auth.isConfigured {
            SignInModal()
        } else {
            ConfigurationNeededView()
        }
    }
}

/// Once an event is selected, everything below is scoped to it — same mental model as
/// the webapp, where every Convex call takes an explicit `eventId` and is checked against
/// `assertEventOrganizerAccess`.
private struct EventScopedTabView: View {
    @EnvironmentObject var auth: ClerkAuthManager

    @StateObject private var picker = EventPickerViewModel()
    @StateObject private var notifications = NotificationsViewModel()
    @StateObject private var navigation = AppNavigationState()

    var body: some View {
        Group {
            if let eventId = picker.selectedEventId {
                let eventName = picker.events.first(where: { $0.id == eventId })?.name ?? "Current event"
                TabView(selection: $navigation.selectedTab) {
                    NavigationStack {
                        DashboardView(eventId: eventId, eventName: eventName, onSelect: selectDashboardDestination)
                    }
                    .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                    .tag(AppTab.dashboard)
                    NavigationStack { AgentChatView(eventId: eventId) }
                        .tabItem { Label("Agent", systemImage: "waveform") }
                    .tag(AppTab.agent)
                    NavigationStack { TasksView(eventId: eventId) }
                        .tabItem { Label("Tasks", systemImage: "checklist") }
                    .tag(AppTab.tasks)
                    NavigationStack { AgendaView(eventId: eventId) }
                        .tabItem { Label("Agenda", systemImage: "calendar") }
                    .tag(AppTab.agenda)
                    NavigationStack(path: $navigation.morePath) {
                        MoreView(
                            eventId: eventId,
                            eventName: eventName,
                            notifications: notifications,
                            reviewerName: auth.userFullName ?? auth.userEmail ?? "Reviewer"
                        )
                    }
                    .tabItem { Label("More", systemImage: "ellipsis.circle") }
                    .tag(AppTab.more)
                }
                .environmentObject(navigation)
                .tint(NamosColor.accent)
            } else if picker.isLoading {
                ProgressView()
            } else {
                EventListView(picker: picker)
            }
        }
        // Authenticate the live client before anything subscribes. The tab content is
        // gated behind the picker having chosen an event, so by the time any view model
        // calls startSubscriptions() the socket is already authenticated.
        .task {
            await ConvexLiveClient.shared.authenticate()
            await picker.refresh()
        }
    }

    private func selectDashboardDestination(_ destination: DashboardDestination) {
        switch destination {
        case .notifications:
            navigation.showMore(.notifications)
        case .tasks:
            navigation.selectedTab = .tasks
        case .agenda:
            navigation.selectedTab = .agenda
        case .checkIn:
            navigation.showMore(.checkIn)
        case .reviews:
            navigation.showMore(.reviews)
        }
    }
}

private struct EventListView: View {
    @ObservedObject var picker: EventPickerViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(picker.events) { event in
                        Button { picker.select(event) } label: {
                            HStack {
                                Text(event.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(NamosColor.text)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(NamosColor.mutedText)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(NamosColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(NamosColor.background)
            .navigationTitle("Your Events")
            .overlay {
                if picker.events.isEmpty && !picker.isLoading {
                    Text("No events yet. Create one on the web dashboard first.")
                        .font(.system(size: 14))
                        .foregroundStyle(NamosColor.mutedText)
                        .multilineTextAlignment(.center)
                        .padding(24)
                }
            }
        }
    }
}

private struct ConfigurationNeededView: View {
    @EnvironmentObject var auth: ClerkAuthManager

    var body: some View {
        VStack(spacing: 12) {
            Text("Configuration needed").font(.system(size: 17, weight: .semibold))
            Text(auth.configurationError ?? "Clerk could not be configured.")
                .font(.system(size: 13))
                .foregroundStyle(NamosColor.warning)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NamosColor.background)
    }
}
