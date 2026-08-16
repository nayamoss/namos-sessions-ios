import Foundation

@MainActor
final class ReviewsViewModel: ObservableObject {
    @Published var queue: [ReviewerQueueRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            queue = try await ConvexClient.shared.query("evaluations:myQueue")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(
        _ row: ReviewerQueueRow,
        reviewerName: String,
        score: Int?,
        comments: String,
        criteriaScores: [CriterionScore]
    ) async -> Bool {
        errorMessage = nil
        var args: [String: Any] = [
            "assignmentId": row.assignmentId,
            "eventId": row.eventId,
            "submissionId": row.submissionId,
            "reviewerName": reviewerName,
        ]
        if let reviewId = row.review?.id { args["id"] = reviewId }
        if let score { args["score"] = score }
        if !comments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { args["comments"] = comments }
        if row.criteria?.isEmpty == false {
            args["criteriaScores"] = criteriaScores.map { score in
                var value: [String: Any] = ["criterionId": score.criterionId]
                if let number = score.value { value["value"] = Int(number) }
                if let text = score.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { value["text"] = text }
                return value
            }
        }
        do {
            let _: ConvexId = try await ConvexClient.shared.mutation("evaluations:save", args: args)
            await refresh()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

private struct EmptyResult: Decodable {}
