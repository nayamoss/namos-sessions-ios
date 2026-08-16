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

    /// Which queries have actually answered. Without this the dashboard cannot tell
    /// "this event has no tasks" from "the tasks query has not come back yet", and it
    /// showed a confident `0` for both.
    @Published private(set) var loadedNotifications = false
    @Published private(set) var loadedTasks = false
    @Published private(set) var loadedAgenda = false
    @Published private(set) var loadedSpeakers = false

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
            loadedNotifications = true
            pendingTasks = (try await tasks).filter { $0.status != "completed" }.count
            loadedTasks = true
            agendaItems = (try await agenda).sorted { $0.startTime < $1.startTime }
            loadedAgenda = true
            reviewQueueCount = (try await queue).count
            updateCheckInProgress(try await speakers)
            loadedSpeakers = true
        } catch {
            // Individual feature tabs surface detailed errors. The dashboard stays stats-only.
        }
    }

    func startSubscriptions() {
        guard let client = ConvexLiveClient.shared.client else {
            Task { await refresh() }
            return
        }

        // Seed from the HTTP path regardless. The live socket is the nicer source, but
        // when it fails to deliver, the tiles would otherwise sit on "loading" forever —
        // which is exactly how the silent-subscription bug hid behind fake zeros before.
        // refresh() is idempotent and the subscriptions overwrite it as soon as they
        // produce anything.
        Task { await refresh() }

        subscriptionTasks.forEach { $0.cancel() }
        subscriptionTasks = [
            Task { [weak self] in
                guard let self else { return }
                let updates = client
                    .subscribe(to: "notifications:unreadCount", with: [:], yielding: Int.self)
                    .catch { _ in Empty() }
                    .values
                for await count in updates {
                    guard !Task.isCancelled else { break }
                    unreadNotifications = count
                    loadedNotifications = true
                }
            },
            Task { [weak self] in
                guard let self else { return }
                let updates = client
                    .subscribe(to: "tasks:list", with: ["eventId": eventId], yielding: [OrganizerTask].self)
                    .catch { _ in Empty() }
                    .values
                for await tasks in updates {
                    guard !Task.isCancelled else { break }
                    pendingTasks = tasks.filter { $0.status != "completed" }.count
                    loadedTasks = true
                }
            },
            Task { [weak self] in
                guard let self else { return }
                let updates = client
                    .subscribe(to: "agenda:list", with: ["eventId": eventId], yielding: [AgendaItem].self)
                    .catch { _ in Empty() }
                    .values
                for await items in updates {
                    guard !Task.isCancelled else { break }
                    agendaItems = items.sorted { $0.startTime < $1.startTime }
                    loadedAgenda = true
                }
            },
            Task { [weak self] in
                guard let self else { return }
                let updates = client
                    .subscribe(to: "evaluations:myQueue", with: [:], yielding: [DashboardReviewerQueueRow].self)
                    .catch { _ in Empty() }
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
                    .catch { _ in Empty() }
                    .values
                for await speakers in updates {
                    guard !Task.isCancelled else { break }
                    updateCheckInProgress(speakers)
                    loadedSpeakers = true
                }
            },
        ]
    }

    // MARK: - Tile states
    //
    // Each tile says one of three things: still loading, a real value, or "there is
    // genuinely nothing here yet." Previously all three collapsed into a bare `0`,
    // `—`, or `0 of 0`, which read as data an organizer could act on.

    var notificationsTile: DashboardTileState {
        guard loadedNotifications else { return .loading }
        return unreadNotifications == 0 ? .empty("All caught up") : .count(unreadNotifications)
    }

    var tasksTile: DashboardTileState {
        guard loadedTasks else { return .loading }
        return pendingTasks == 0 ? .empty("Nothing outstanding") : .count(pendingTasks)
    }

    var agendaTile: DashboardTileState {
        guard loadedAgenda else { return .loading }
        if let item = currentOrNextAgendaItem { return .text(item.title) }
        return .empty(agendaItems.isEmpty ? "No agenda yet" : "Nothing left today")
    }

    var checkInTile: DashboardTileState {
        guard loadedSpeakers else { return .loading }
        // "0 of 0" was the worst offender: it looked like a real ratio for an event
        // that simply has no speakers on it yet.
        guard speakerCount > 0 else { return .empty("No speakers yet") }
        return .text("\(checkedInSpeakers) of \(speakerCount)")
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
