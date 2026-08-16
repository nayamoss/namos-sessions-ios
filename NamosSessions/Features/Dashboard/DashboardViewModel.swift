import Combine
import ConvexMobile
import Foundation

/// Collects the existing event-scoped and caller-scoped dashboard queries. Each count
/// remains derived from its source query so the dashboard adds no backend surface.
@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var unreadNotifications = 0
    @Published var pendingTasks = 0
    @Published var agendaItems: [AgendaItem] = []
    @Published var reviewQueueCount = 0
    @Published var checkedInSpeakers = 0
    @Published var speakerCount = 0
    @Published var isLoading = false

    let eventId: ConvexId
    private var subscriptionTasks: [Task<Void, Never>] = []

    init(eventId: ConvexId) {
        self.eventId = eventId
    }

    deinit {
        subscriptionTasks.forEach { $0.cancel() }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let unread: Int = ConvexClient.shared.query("notifications:unreadCount")
            async let tasks: [OrganizerTask] = ConvexClient.shared.query("tasks:list", args: ["eventId": eventId])
            async let agenda: [AgendaItem] = ConvexClient.shared.query("agenda:list", args: ["eventId": eventId])
            async let queue: [DashboardReviewerQueueRow] = ConvexClient.shared.query("evaluations:myQueue")
            async let speakers: [Speaker] = ConvexClient.shared.query("speakers:list", args: ["eventId": eventId])

            unreadNotifications = try await unread
            pendingTasks = (try await tasks).filter { $0.status != "completed" }.count
            agendaItems = (try await agenda).sorted { $0.startTime < $1.startTime }
            reviewQueueCount = (try await queue).count
            updateCheckInProgress(try await speakers)
        } catch {
            // Individual feature tabs surface detailed errors. The dashboard stays stats-only.
        }
    }

    func startSubscriptions() {
        guard let client = ConvexLiveClient.shared.client else {
            Task { await refresh() }
            return
        }

        subscriptionTasks.forEach { $0.cancel() }
        subscriptionTasks = [
            Task { [weak self] in
                guard let self else { return }
                let updates = client
                    .subscribe(to: "notifications:unreadCount", with: [:], yielding: Int.self)
                    .replaceError(with: 0)
                    .values
                for await count in updates {
                    guard !Task.isCancelled else { break }
                    unreadNotifications = count
                }
            },
            Task { [weak self] in
                guard let self else { return }
                let updates = client
                    .subscribe(to: "tasks:list", with: ["eventId": eventId], yielding: [OrganizerTask].self)
                    .replaceError(with: [])
                    .values
                for await tasks in updates {
                    guard !Task.isCancelled else { break }
                    pendingTasks = tasks.filter { $0.status != "completed" }.count
                }
            },
            Task { [weak self] in
                guard let self else { return }
                let updates = client
                    .subscribe(to: "agenda:list", with: ["eventId": eventId], yielding: [AgendaItem].self)
                    .replaceError(with: [])
                    .values
                for await items in updates {
                    guard !Task.isCancelled else { break }
                    agendaItems = items.sorted { $0.startTime < $1.startTime }
                }
            },
            Task { [weak self] in
                guard let self else { return }
                let updates = client
                    .subscribe(to: "evaluations:myQueue", with: [:], yielding: [DashboardReviewerQueueRow].self)
                    .replaceError(with: [])
                    .values
                for await queue in updates {
                    guard !Task.isCancelled else { break }
                    reviewQueueCount = queue.count
                }
            },
            Task { [weak self] in
                guard let self else { return }
                let updates = client
                    .subscribe(to: "speakers:list", with: ["eventId": eventId], yielding: [Speaker].self)
                    .replaceError(with: [])
                    .values
                for await speakers in updates {
                    guard !Task.isCancelled else { break }
                    updateCheckInProgress(speakers)
                }
            },
        ]
    }

    /// Kept in lockstep with AgendaViewModel so the dashboard and agenda screen agree on
    /// what is currently underway.
    var happeningNow: AgendaItem? {
        let now = Date()
        return agendaItems.first { $0.startDate <= now && now <= $0.endDate }
    }

    var nextAgendaItem: AgendaItem? {
        let now = Date()
        return agendaItems.first { $0.startDate > now }
    }

    var currentOrNextAgendaItem: AgendaItem? {
        happeningNow ?? nextAgendaItem
    }

    private func updateCheckInProgress(_ speakers: [Speaker]) {
        checkedInSpeakers = speakers.filter { $0.checkedInAt != nil }.count
        speakerCount = speakers.count
    }
}

/// The dashboard only needs the queue length. Convex ignores fields not represented by a
/// Decodable type, leaving the full row model owned by the Reviews feature.
private struct DashboardReviewerQueueRow: Decodable {}
