import Combine
import Foundation

/// Keeps the door-facing speaker list in sync across organizers while retaining the
/// HTTP request fallback when live configuration is unavailable.
@MainActor
final class CheckInViewModel: ObservableObject {
    @Published var speakers: [Speaker] = []
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
            let result: [Speaker] = try await ConvexClient.shared.query("speakers:list", args: ["eventId": eventId])
            speakers = sorted(result)
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
                .subscribe(to: "speakers:list", with: ["eventId": eventId], yielding: [Speaker].self)
                .catch { _ in Empty() }
                .values
            for await speakers in updates {
                guard !Task.isCancelled else { break }
                self.speakers = self.sorted(speakers)
            }
        }
    }

    func toggleCheckIn(_ speaker: Speaker) async {
        let wasCheckedIn = speaker.isCheckedIn
        if let index = speakers.firstIndex(where: { $0.id == speaker.id }) {
            speakers[index] = Speaker(
                _id: speaker._id,
                eventId: speaker.eventId,
                firstName: speaker.firstName,
                lastName: speaker.lastName,
                email: speaker.email,
                confirmationStatus: speaker.confirmationStatus,
                checkedInAt: wasCheckedIn ? nil : Date().timeIntervalSince1970 * 1_000,
                checkedInByUserId: speaker.checkedInByUserId
            )
            speakers = sorted(speakers)
        }

        do {
            let path = wasCheckedIn ? "speakers:undoCheckIn" : "speakers:checkIn"
            let _: EmptyResult = try await ConvexClient.shared.mutation(path, args: [
                "eventId": eventId,
                "speakerId": speaker.id,
            ])
        } catch {
            errorMessage = error.localizedDescription
            await refresh()
        }
    }

    private func sorted(_ speakers: [Speaker]) -> [Speaker] {
        speakers.sorted {
            if $0.isCheckedIn != $1.isCheckedIn { return !$0.isCheckedIn }
            return $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
        }
    }
}

private struct EmptyResult: Decodable {}
