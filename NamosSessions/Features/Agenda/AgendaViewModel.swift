import Foundation
import Combine

/// Reads the same `agenda_items` the webapp's program builder writes (convex/agenda.ts:
/// `list`). Organizers can make focused, on-the-go schedule corrections while preserving
/// the fields that belong to the fuller web editor.
@MainActor
final class AgendaViewModel: ObservableObject {
    @Published var items: [AgendaItem] = []
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
            let result: [AgendaItem] = try await ConvexClient.shared.query("agenda:list", args: ["eventId": eventId])
            items = result.sorted { $0.startTime < $1.startTime }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

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
                .subscribe(to: "agenda:list", with: ["eventId": eventId], yielding: [AgendaItem].self)
                .catch { _ in Empty() }
                .values
            for await items in updates {
                guard !Task.isCancelled else { break }
                self.items = items.sorted { $0.startTime < $1.startTime }
            }
        }
    }

    func loadRooms() async throws -> [NamosRoom] {
        let rooms: [NamosRoom] = try await ConvexClient.shared.query("events:listRooms", args: ["eventId": eventId])
        return rooms.sorted { $0.sortOrder < $1.sortOrder }
    }

    func conflicts(for item: AgendaItem) async throws -> [AgendaConflict] {
        let allConflicts: [AgendaConflict] = try await ConvexClient.shared.query("agenda:detectConflicts", args: ["eventId": eventId])
        return allConflicts.filter { $0.itemA == item.id || $0.itemB == item.id }
    }

    func saveItem(_ item: AgendaItem) async -> Bool {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return false }
        let original = items[index]
        items[index] = item
        items.sort { $0.startTime < $1.startTime }
        errorMessage = nil
        do {
            var args: [String: Any] = [
                "id": item.id,
                "eventId": item.eventId,
                "title": item.title,
                "roomId": item.roomId,
                "startTime": item.startTime,
                "endTime": item.endTime,
                "speakerIds": item.speakerIds,
                "isPublished": item.isPublished,
            ]
            if let trackId = item.trackId { args["trackId"] = trackId }
            if let videoUrl = item.videoUrl { args["videoUrl"] = videoUrl }
            if let locationDetails = item.locationDetails { args["locationDetails"] = locationDetails }
            let _: ConvexId = try await ConvexClient.shared.mutation("agenda:save", args: args)
            return true
        } catch {
            errorMessage = error.localizedDescription
            // Restore immediately, then refresh to ensure server truth wins if live data changed.
            if let currentIndex = items.firstIndex(where: { $0.id == original.id }) {
                items[currentIndex] = original
                items.sort { $0.startTime < $1.startTime }
            }
            await refresh()
            return false
        }
    }

    var happeningNow: AgendaItem? {
        let now = Date()
        return items.first { $0.startDate <= now && now <= $0.endDate }
    }
}
