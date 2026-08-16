import Foundation

/// `events:listMine` (convex/events.ts) — the same organizer/reviewer membership scoping
/// the webapp's event switcher uses. An organizer only ever sees events they belong to.
@MainActor
final class EventPickerViewModel: ObservableObject {
    @Published var events: [NamosEvent] = []
    @Published var selectedEventId: ConvexId?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            events = try await ConvexClient.shared.query("events:listMine")
            if selectedEventId == nil {
                selectedEventId = KeychainService.shared.getLastSelectedEventId() ?? events.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ event: NamosEvent) {
        selectedEventId = event.id
        KeychainService.shared.saveLastSelectedEventId(event.id)
    }
}
