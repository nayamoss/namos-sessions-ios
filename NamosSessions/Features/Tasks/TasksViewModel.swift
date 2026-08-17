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
    /// Backs the main Tasks list's group-by-person toggle — id -> display name, used to
    /// label each task's speaker/sponsor without adding a new backend surface.
    @Published var speakerNames: [ConvexId: String] = [:]
    @Published var sponsorNames: [ConvexId: String] = [:]

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
        // Seed from the HTTP path, which is authenticated per request and works even
        // when the live socket does not deliver. Without this the screen sits on its
        // initial empty value indefinitely.
        Task { await refresh() }

        subscriptionTask?.cancel()
        subscriptionTask = Task { [weak self] in
            guard let self else { return }
            let updates = client
                .subscribe(to: "tasks:list", with: ["eventId": eventId], yielding: [OrganizerTask].self)
                .handleEvents(
                    receiveOutput: { _ in
                        print("✅ Convex live subscription delivered tasks:list.")
                    },
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("⚠️ Convex live subscription failed for tasks:list: \(String(reflecting: error))")
                        }
                    }
                )
                .catch { _ in Empty() }
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
            tasks[index] = OrganizerTask(_id: task._id, eventId: task.eventId, title: task.title, description: task.description, status: newStatus, targetType: task.targetType, dueDate: task.dueDate, source: task.source, speakerId: task.speakerId, sponsorId: task.sponsorId, submissionId: task.submissionId)
        }
        do {
            let _: EmptyResult = try await ConvexClient.shared.mutation("tasks:setStatus", args: ["id": task.id, "status": newStatus])
        } catch {
            errorMessage = error.localizedDescription
            await refresh() // roll back to server truth on failure
        }
    }

    /// Feeds the group-by-person filter's labels. Cheap at current event sizes (same
    /// pattern SponsorsViewModel already uses to fetch two lists side by side) and only
    /// needs to happen once — names rarely change mid-session.
    func loadPersonNames() async {
        async let speakersResult: [Speaker] = ConvexClient.shared.query("speakers:list", args: ["eventId": eventId])
        async let sponsorsResult: [Sponsor] = ConvexClient.shared.query("sponsors:list", args: ["eventId": eventId])
        do {
            let speakers = try await speakersResult
            speakerNames = Dictionary(uniqueKeysWithValues: speakers.map { ($0.id, $0.fullName) })
        } catch {
            // Non-fatal — the grouped view falls back to showing raw ids rather than
            // blocking the whole Tasks screen over a names lookup.
        }
        do {
            let sponsors = try await sponsorsResult
            sponsorNames = Dictionary(uniqueKeysWithValues: sponsors.map { ($0.id, $0.name) })
        } catch {
            // Same fallback as above.
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
