import Combine
import Foundation

@MainActor
final class SponsorsViewModel: ObservableObject {
    @Published var sponsors: [Sponsor] = []
    @Published var tiers: [SponsorTier] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let eventId: ConvexId
    private var subscriptionTask: Task<Void, Never>?

    init(eventId: ConvexId) { self.eventId = eventId }
    deinit { subscriptionTask?.cancel() }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let sponsorResult: [Sponsor] = ConvexClient.shared.query("sponsors:list", args: ["eventId": eventId])
            async let tierResult: [SponsorTier] = ConvexClient.shared.query("sponsorTiers:list", args: ["eventId": eventId])
            sponsors = sort(try await sponsorResult)
            tiers = try await tierResult
        } catch { errorMessage = error.localizedDescription }
    }

    func startSubscription() {
        guard let client = ConvexLiveClient.shared.client else { Task { await refresh() }; return }
        // Seed from the HTTP path, which is authenticated per request and works even
        // when the live socket does not deliver. Without this the screen sits on its
        // initial empty value indefinitely.
        Task { await refresh() }

        subscriptionTask?.cancel()
        subscriptionTask = Task { [weak self] in
            guard let self else { return }
            let updates = client.subscribe(to: "sponsors:list", with: ["eventId": eventId], yielding: [Sponsor].self)
                .catch { _ in Empty() }.values
            for await sponsors in updates {
                guard !Task.isCancelled else { break }
                self.sponsors = self.sort(sponsors)
            }
        }
        Task {
            do { tiers = try await ConvexClient.shared.query("sponsorTiers:list", args: ["eventId": eventId]) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    func save(_ sponsor: Sponsor?, name: String, tierId: ConvexId?, status: String, website: String, notes: String) async -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return false }
        errorMessage = nil
        let cleanWebsite = website.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if let sponsor {
                let optimistic = Sponsor(_id: sponsor._id, eventId: sponsor.eventId, tierId: tierId,
                    name: cleanName, status: status, website: cleanWebsite, notes: cleanNotes,
                    tier: tiers.first(where: { $0.id == tierId }), primaryContact: sponsor.primaryContact,
                    openTaskCount: sponsor.openTaskCount)
                if let index = sponsors.firstIndex(where: { $0.id == sponsor.id }) {
                    sponsors[index] = optimistic
                    sponsors = sort(sponsors)
                }
                var args: [String: Any] = ["sponsorId": sponsor.id, "name": cleanName,
                    "tierId": tierId ?? NSNull(), "status": status, "website": cleanWebsite, "notes": cleanNotes]
                let _: EmptyResult = try await ConvexClient.shared.mutation("sponsors:update", args: args)
            } else {
                var args: [String: Any] = ["eventId": eventId, "name": cleanName,
                    "status": status, "website": cleanWebsite, "notes": cleanNotes]
                if let tierId { args["tierId"] = tierId }
                let _: ConvexId = try await ConvexClient.shared.mutation("sponsors:create", args: args)
            }
            await refresh()
            return true
        } catch {
            errorMessage = error.localizedDescription
            await refresh()
            return false
        }
    }

    func remove(_ sponsor: Sponsor) async {
        let previous = sponsors
        sponsors.removeAll { $0.id == sponsor.id }
        errorMessage = nil
        do {
            let _: EmptyResult = try await ConvexClient.shared.mutation("sponsors:remove", args: ["sponsorId": sponsor.id])
        } catch {
            sponsors = previous
            errorMessage = error.localizedDescription
        }
    }

    private func sort(_ sponsors: [Sponsor]) -> [Sponsor] {
        sponsors.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private struct EmptyResult: Decodable {}
