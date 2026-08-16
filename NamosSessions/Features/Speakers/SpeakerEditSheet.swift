import SwiftUI

struct SpeakerEditSheet: View {
    private enum ConfirmationStatus: String, CaseIterable, Identifiable {
        case awaiting
        case confirmed
        case declined

        var id: Self { self }

        var title: String { rawValue.capitalized }
    }

    @Environment(\.dismiss) private var dismiss
    let speaker: Speaker?
    let errorMessage: String?
    let onSave: (String, String, String, String) async -> Bool

    @State private var firstName: String
    @State private var lastName: String
    @State private var email: String
    @State private var confirmationStatus: ConfirmationStatus
    @State private var isSaving = false

    init(speaker: Speaker?, errorMessage: String?, onSave: @escaping (String, String, String, String) async -> Bool) {
        self.speaker = speaker
        self.errorMessage = errorMessage
        self.onSave = onSave
        _firstName = State(initialValue: speaker?.firstName ?? "")
        _lastName = State(initialValue: speaker?.lastName ?? "")
        _email = State(initialValue: speaker?.email ?? "")
        _confirmationStatus = State(initialValue: ConfirmationStatus(rawValue: speaker?.confirmationStatus ?? "awaiting") ?? .awaiting)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Speaker") {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                        .autocorrectionDisabled()
                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                        .autocorrectionDisabled()
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Confirmation") {
                    Picker("Confirmation status", selection: $confirmationStatus) {
                        ForEach(ConfirmationStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(NamosColor.warning)
                }
            }
            .navigationTitle(speaker == nil ? "Add Speaker" : "Edit Speaker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            let didSave = await onSave(firstName, lastName, email, confirmationStatus.rawValue)
                            isSaving = false
                            if didSave { dismiss() }
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }
}

private struct EmptyResult: Decodable {}
