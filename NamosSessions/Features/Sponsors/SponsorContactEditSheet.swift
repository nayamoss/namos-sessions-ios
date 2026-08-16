import SwiftUI

struct SponsorContactEditSheet: View {
    let sponsorId: ConvexId
    let onSaved: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var role = ""
    @State private var isPrimary = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                    TextField("Role", text: $role)
                }
                Section { Toggle("Primary contact", isOn: $isPrimary) } footer: { Text("The first contact is automatically set as primary.") }
                if let errorMessage { Text(errorMessage).font(.system(size: 13)).foregroundStyle(NamosColor.warning) }
            }.navigationTitle("New Contact")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving) }
                }
        }
    }
    private func save() async {
        isSaving = true; errorMessage = nil; defer { isSaving = false }
        do {
            let _: ConvexId = try await ConvexClient.shared.mutation("sponsorContacts:create", args: ["sponsorId": sponsorId,
                "name": name.trimmingCharacters(in: .whitespacesAndNewlines), "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
                "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines), "role": role.trimmingCharacters(in: .whitespacesAndNewlines), "isPrimary": isPrimary])
            await onSaved(); dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct EmptyResult: Decodable {}
