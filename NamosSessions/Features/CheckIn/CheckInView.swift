import SwiftUI

struct CheckInView: View {
    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case notCheckedIn = "Not checked in"

        var id: Self { self }
    }

    @StateObject private var viewModel: CheckInViewModel
    @State private var searchText = ""
    @State private var filter: Filter = .all

    init(eventId: ConvexId) {
        _viewModel = StateObject(wrappedValue: CheckInViewModel(eventId: eventId))
    }

    private var filteredSpeakers: [Speaker] {
        viewModel.speakers.filter { speaker in
            let matchesFilter = filter == .all || !speaker.isCheckedIn
            let matchesSearch = searchText.isEmpty || speaker.fullName.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                Picker("Check-in filter", selection: $filter) {
                    ForEach(Filter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 2)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(NamosColor.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(filteredSpeakers) { speaker in
                    CheckInRow(speaker: speaker) {
                        Task { await viewModel.toggleCheckIn(speaker) }
                    }
                }

                if viewModel.speakers.isEmpty && !viewModel.isLoading {
                    Text("No speakers for this event yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(NamosColor.mutedText)
                        .padding(.top, 40)
                }
            }
            .padding(16)
        }
        .background(NamosColor.background)
        .navigationTitle("Check-in")
        .searchable(text: $searchText, prompt: "Search speakers")
        .refreshable { await viewModel.refresh() }
        .task { viewModel.startSubscription() }
    }
}

private struct CheckInRow: View {
    let speaker: Speaker
    let onToggle: () -> Void

    private var initials: String {
        let first = speaker.firstName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)
        let last = speaker.lastName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)
        return "\(first)\(last)".uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(initials)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NamosColor.accent)
                .frame(width: 42, height: 42)
                .background(NamosColor.background)
                .clipShape(Circle())

            Text(speaker.fullName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(NamosColor.text)

            Spacer()

            Button(action: onToggle) {
                Image(systemName: speaker.isCheckedIn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(speaker.isCheckedIn ? NamosColor.accent : NamosColor.mutedText)
            }
            .accessibilityLabel(speaker.isCheckedIn ? "Undo check-in for \(speaker.fullName)" : "Check in \(speaker.fullName)")
        }
        .padding(14)
        .background(NamosColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
