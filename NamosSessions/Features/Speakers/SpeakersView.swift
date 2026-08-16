import SwiftUI

struct SpeakersView: View {
    @StateObject private var viewModel: SpeakersViewModel
    @State private var searchText = ""
    @State private var editingSpeaker: Speaker?
    @State private var isEditorPresented = false

    init(eventId: ConvexId) {
        _viewModel = StateObject(wrappedValue: SpeakersViewModel(eventId: eventId))
    }

    private var filteredSpeakers: [Speaker] {
        guard !searchText.isEmpty else { return viewModel.speakers }
        return viewModel.speakers.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(NamosColor.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(filteredSpeakers) { speaker in
                    HStack(spacing: 8) {
                        Button {
                            editingSpeaker = speaker
                            isEditorPresented = true
                        } label: {
                            SpeakerRow(speaker: speaker)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit \(speaker.fullName)")

                        // Their outstanding items, from the by_speaker index that has
                        // always existed but had no way in from the phone.
                        NavigationLink {
                            PersonTasksView(
                                eventId: viewModel.eventId,
                                person: .speaker(id: speaker.id, name: speaker.fullName)
                            )
                        } label: {
                            Image(systemName: "checklist")
                                .font(.system(size: 16))
                                .foregroundStyle(NamosColor.mutedText)
                                .frame(width: 40, height: 40)
                                .background(NamosColor.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .accessibilityLabel("Tasks for \(speaker.fullName)")
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
        .navigationTitle("Speakers")
        .searchable(text: $searchText, prompt: "Search speakers")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingSpeaker = nil
                    isEditorPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add speaker")
            }
        }
        .refreshable { await viewModel.refresh() }
        .task { viewModel.startSubscription() }
        .sheet(isPresented: $isEditorPresented, onDismiss: { editingSpeaker = nil }) {
            SpeakerEditSheet(speaker: editingSpeaker, errorMessage: viewModel.errorMessage) { firstName, lastName, email, confirmationStatus in
                if let editingSpeaker {
                    return await viewModel.updateSpeaker(
                        editingSpeaker,
                        firstName: firstName,
                        lastName: lastName,
                        email: email,
                        confirmationStatus: confirmationStatus
                    )
                }
                return await viewModel.createSpeaker(
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    confirmationStatus: confirmationStatus
                )
            }
            .id(editingSpeaker?.id ?? "new-speaker")
        }
    }
}

private struct SpeakerRow: View {
    let speaker: Speaker

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(speaker.fullName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(NamosColor.text)
                Text(speaker.email)
                    .font(.system(size: 13))
                    .foregroundStyle(NamosColor.mutedText)
            }

            Spacer()

            Text(speaker.confirmationStatusLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NamosColor.mutedText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NamosColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct EmptyResult: Decodable {}
