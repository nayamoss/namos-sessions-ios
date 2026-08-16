import SwiftUI

struct SubmissionsView: View {
    @StateObject private var viewModel: SubmissionsViewModel
    @State private var filter = "pending"

    init(eventId: ConvexId) { _viewModel = StateObject(wrappedValue: SubmissionsViewModel(eventId: eventId)) }

    private var filtered: [Submission] { viewModel.submissions.filter { $0.status == filter } }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Status", selection: $filter) {
                Text("Pending").tag("pending")
                Text("Accepted").tag("accepted")
                Text("Declined").tag("declined")
            }
            .pickerStyle(.segmented).padding(16)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let errorMessage = viewModel.errorMessage { Text(errorMessage).font(.system(size: 13)).foregroundStyle(NamosColor.warning) }
                    ForEach(filtered) { submission in
                        NavigationLink { SubmissionDetailView(submission: submission, viewModel: viewModel) } label: { SubmissionRow(submission: submission) }
                            .buttonStyle(.plain)
                    }
                    if filtered.isEmpty && !viewModel.isLoading { Text("No \(filter) submissions.").font(.system(size: 14)).foregroundStyle(NamosColor.mutedText).padding(.top, 40) }
                }.padding(.horizontal, 16)
            }
        }
        .background(NamosColor.background).navigationTitle("Submissions")
        .refreshable { await viewModel.refresh() }.task { await viewModel.refresh() }
    }
}

private struct SubmissionRow: View {
    let submission: Submission
    var body: some View {
        HStack {
            Text(submission.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(NamosColor.text)
            Spacer()
            Text(submission.status.capitalized).font(.system(size: 12, weight: .medium)).foregroundStyle(NamosColor.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14).background(NamosColor.surface).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SubmissionDetailView: View {
    let submission: Submission
    @ObservedObject var viewModel: SubmissionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isDeciding = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(submission.title).font(.system(size: 22, weight: .semibold)).foregroundStyle(NamosColor.text)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(submission.answers.keys.sorted(), id: \.self) { key in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(key).font(.system(size: 13, weight: .medium)).foregroundStyle(NamosColor.mutedText)
                            Text(submission.answers[key]?.displayValue ?? "—").font(.system(size: 16)).foregroundStyle(NamosColor.text)
                        }
                    }
                }
                if submission.status == "pending" {
                    HStack(spacing: 12) {
                        Button("Decline") { Task { await decide("declined") } }
                            .foregroundStyle(NamosColor.warning)
                            .frame(maxWidth: .infinity).padding(12)
                            .background(NamosColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Button("Accept") { Task { await decide("accepted") } }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(12)
                            .background(NamosColor.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }.disabled(isDeciding)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }
        .background(NamosColor.background).navigationTitle("Submission").navigationBarTitleDisplayMode(.inline)
    }

    private func decide(_ status: String) async { isDeciding = true; if await viewModel.decide(submission, status: status) { dismiss() }; isDeciding = false }
}
