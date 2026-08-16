import Combine
import Foundation

@MainActor
final class SpeakersViewModel: ObservableObject {
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

    func createSpeaker(firstName: String, lastName: String, email: String, confirmationStatus: String) async -> Bool {
        let firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !firstName.isEmpty, !lastName.isEmpty, !email.isEmpty else {
            errorMessage = "First name, last name, and email are required."
            return false
        }

        errorMessage = nil
        let temporaryId = "temporary-speaker-\(UUID().uuidString)"
        let temporarySpeaker = Speaker(
            _id: temporaryId,
            eventId: eventId,
            firstName: firstName,
            lastName: lastName,
            email: email,
            confirmationStatus: confirmationStatus,
            checkedInAt: nil,
            checkedInByUserId: nil
        )
        speakers = sorted(speakers + [temporarySpeaker])

        do {
            let speakerId: ConvexId = try await ConvexClient.shared.mutation("speakers:create", args: [
                "eventId": eventId,
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "confirmationStatus": confirmationStatus,
            ])
            if let index = speakers.firstIndex(where: { $0.id == temporaryId }) {
                speakers[index] = Speaker(
                    _id: speakerId,
                    eventId: eventId,
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    confirmationStatus: confirmationStatus,
                    checkedInAt: nil,
                    checkedInByUserId: nil
                )
                speakers = sorted(speakers)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            speakers.removeAll { $0.id == temporaryId }
            await refresh()
            return false
        }
    }

    func updateSpeaker(_ speaker: Speaker, firstName: String, lastName: String, email: String, confirmationStatus: String) async -> Bool {
        let firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !firstName.isEmpty, !lastName.isEmpty, !email.isEmpty else {
            errorMessage = "First name, last name, and email are required."
            return false
        }

        errorMessage = nil
        let updatedSpeaker = Speaker(
            _id: speaker._id,
            eventId: speaker.eventId,
            firstName: firstName,
            lastName: lastName,
            email: email,
            confirmationStatus: confirmationStatus,
            checkedInAt: speaker.checkedInAt,
            checkedInByUserId: speaker.checkedInByUserId
        )
        if let index = speakers.firstIndex(where: { $0.id == speaker.id }) {
            speakers[index] = updatedSpeaker
            speakers = sorted(speakers)
        }

        do {
            let _: EmptyResult = try await ConvexClient.shared.mutation("speakers:organizerUpdate", args: [
                "eventId": eventId,
                "speakerId": speaker.id,
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "confirmationStatus": confirmationStatus,
            ])
            return true
        } catch {
            errorMessage = error.localizedDescription
            if let index = speakers.firstIndex(where: { $0.id == speaker.id }) {
                speakers[index] = speaker
                speakers = sorted(speakers)
            }
            await refresh()
            return false
        }
    }

    private func sorted(_ speakers: [Speaker]) -> [Speaker] {
        speakers.sorted {
            $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
        }
    }
}

private struct EmptyResult: Decodable {}
