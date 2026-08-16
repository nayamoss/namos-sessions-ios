import Foundation
import Combine

/// Reads/writes the exact same `onboarding_tasks` rows the webapp's Tasks admin uses
/// (convex/tasks.ts: `list`, `setStatus`) — checking a task off on the phone in the
/// hallway is visible on the organizer dashboard immediately (once this is upgraded
/// from polling to live subscriptions; see ConvexClient's header comment).
@MainActor
final class TasksViewModel: ObservableObject {
    @Published var tasks: [OrganizerTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let eventId: ConvexId
    private var subscriptionTask: Task<Void, Never>?

    init(eventId: ConvexId) {
        self.eventId = eventId
    }

    deinit {
        subscriptionTask?.cancel()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            tasks = try await ConvexClient.shared.query("tasks:list", args: ["eventId": eventId])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The HTTP request remains the fallback for a missing deployment config; otherwise
    /// ConvexMobile owns the WebSocket and pushes every task change to this view model.
    func startSubscription() {
        guard let client = ConvexLiveClient.shared.client else {
            Task { await refresh() }
            return
        }
        subscriptionTask?.cancel()
        subscriptionTask = Task { [weak self] in
            guard let self else { return }
            let updates = client
                .subscribe(to: "tasks:list", with: ["eventId": eventId], yielding: [OrganizerTask].self)
                .replaceError(with: [])
                .values
            for await tasks in updates {
                guard !Task.isCancelled else { break }
                self.tasks = tasks
            }
        }
    }

    func toggleComplete(_ task: OrganizerTask) async {
        let newStatus = task.isDone ? "pending" : "completed"
        // Optimistic — an organizer tapping a checkbox on the go shouldn't wait on a round trip.
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = OrganizerTask(_id: task._id, eventId: task.eventId, title: task.title, description: task.description, status: newStatus, targetType: task.targetType, dueDate: task.dueDate, source: task.source)
        }
        do {
            let _: EmptyResult = try await ConvexClient.shared.mutation("tasks:setStatus", args: ["id": task.id, "status": newStatus])
        } catch {
            errorMessage = error.localizedDescription
            await refresh() // roll back to server truth on failure
        }
    }

    func createTask(title: String, targetType: String) async -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        errorMessage = nil
        do {
            let _: ConvexId = try await ConvexClient.shared.mutation("tasks:create", args: [
                "eventId": eventId,
                "title": title,
                "targetType": targetType,
            ])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

private struct EmptyResult: Decodable {}
