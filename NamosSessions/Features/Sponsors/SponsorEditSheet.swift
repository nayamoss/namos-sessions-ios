import SwiftUI

struct SponsorEditSheet: View {
    let sponsor: Sponsor?
    let tiers: [SponsorTier]
    @ObservedObject var viewModel: SponsorsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var tierId: ConvexId?
    @State private var status: String
    @State private var website: String
    @State private var notes: String
    @State private var isSaving = false

    init(sponsor: Sponsor?, tiers: [SponsorTier], viewModel: SponsorsViewModel) {
        self.sponsor = sponsor; self.tiers = tiers; self.viewModel = viewModel
        _name = State(initialValue: sponsor?.name ?? ""); _tierId = State(initialValue: sponsor?.tierId)
        _status = State(initialValue: sponsor?.status ?? "prospect"); _website = State(initialValue: sponsor?.website ?? "")
        _notes = State(initialValue: sponsor?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sponsor") {
                    TextField("Name", text: $name)
                    Picker("Tier", selection: $tierId) {
                        Text("No tier").tag(Optional<ConvexId>.none)
                        ForEach(tiers) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Picker("Status", selection: $status) {
                        Text("Prospect").tag("prospect"); Text("Confirmed").tag("confirmed"); Text("Declined").tag("declined")
                    }
                }
                Section("Details") {
                    TextField("Website", text: $website).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                if let errorMessage = viewModel.errorMessage { Text(errorMessage).font(.system(size: 13)).foregroundStyle(NamosColor.warning) }
            }
            .navigationTitle(sponsor == nil ? "New Sponsor" : "Edit Sponsor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving) }
            }
        }
    }
    private func save() async {
        isSaving = true
        if await viewModel.save(sponsor, name: name, tierId: tierId, status: status, website: website, notes: notes) { dismiss() }
        isSaving = false
    }
}
