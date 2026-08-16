import SwiftUI

/// A non-empty caller-scoped queue is the role signal: reviewers go directly to their
/// assignments; an empty queue falls back to the organizer-only submissions query.
struct ReviewsHubView: View {
    let eventId: ConvexId
    let reviewerName: String
    @State private var queue: [ReviewerQueueRow]?
    @State private var queueError: String?

    var body: some View {
        Group {
            if let queue, !queue.isEmpty {
                ReviewsView(reviewerName: reviewerName)
            } else if queue != nil {
                SubmissionsView(eventId: eventId)
            } else if let queueError {
                ContentUnavailableView("Reviews unavailable", systemImage: "exclamationmark.triangle", description: Text(queueError))
            } else {
                ProgressView()
            }
        }
        .task {
            do { queue = try await ConvexClient.shared.query("evaluations:myQueue") }
            catch { queueError = error.localizedDescription }
        }
    }
}
