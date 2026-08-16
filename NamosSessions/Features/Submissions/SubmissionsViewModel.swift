import Foundation

@MainActor
final class SubmissionsViewModel: ObservableObject {
    @Published var submissions: [Submission] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    let eventId: ConvexId

    init(eventId: ConvexId) { self.eventId = eventId }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { submissions = try await ConvexClient.shared.query("submissions:list", args: ["eventId": eventId]) }
        catch { errorMessage = error.localizedDescription }
    }

    func decide(_ submission: Submission, status: String) async -> Bool {
        guard let index = submissions.firstIndex(where: { $0.id == submission.id }) else { return false }
        let prior = submissions[index]
        submissions[index] = Submission(_id: prior._id, eventId: prior.eventId, formId: prior.formId, speakerId: prior.speakerId, title: prior.title, status: status, answers: prior.answers, submittedAt: prior.submittedAt, createdAt: prior.createdAt, updatedAt: prior.updatedAt)
        do {
            let _: Submission = try await ConvexClient.shared.mutation("submissions:decide", args: ["submissionId": submission.id, "status": status])
            return true
        } catch {
            errorMessage = error.localizedDescription
            await refresh()
            return false
        }
    }
}

private struct EmptyResult: Decodable {}
