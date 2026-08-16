import SwiftUI

struct ReviewsView: View {
    @StateObject private var viewModel = ReviewsViewModel()
    @State private var selectedReview: ReviewerQueueRow?
    let reviewerName: String

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(.system(size: 13)).foregroundStyle(NamosColor.warning)
                }
                ForEach(viewModel.queue) { row in
                    Button { selectedReview = row } label: { ReviewRow(row: row) }
                        .buttonStyle(.plain)
                }
                if viewModel.queue.isEmpty && !viewModel.isLoading {
                    Text("No reviews assigned to you.")
                        .font(.system(size: 14)).foregroundStyle(NamosColor.mutedText).padding(.top, 40)
                }
            }
            .padding(16)
        }
        .background(NamosColor.background)
        .navigationTitle("Reviews")
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.refresh() }
        .sheet(item: $selectedReview) { row in
            ReviewScoringSheet(row: row, reviewerName: reviewerName) { score, comments, criteriaScores in
                await viewModel.save(row, reviewerName: reviewerName, score: score, comments: comments, criteriaScores: criteriaScores)
            }
        }
    }
}

private struct ReviewRow: View {
    let row: ReviewerQueueRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(row.submissionTitle).font(.system(size: 16, weight: .semibold)).foregroundStyle(NamosColor.text)
                Text("Round \(Int(row.round)) · \(row.planName)").font(.system(size: 13)).foregroundStyle(NamosColor.mutedText)
                if !row.anonymized, let names = row.speakerNames, !names.isEmpty {
                    Text(names.joined(separator: ", ")).font(.system(size: 13)).foregroundStyle(NamosColor.mutedText)
                }
            }
            Spacer()
            Text(row.isComplete ? "Scored" : "To score")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(row.isComplete ? NamosColor.mutedText : NamosColor.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(NamosColor.surface).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
