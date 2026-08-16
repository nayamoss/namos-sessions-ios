import SwiftUI

struct SponsorDetailView: View {
    let sponsor: Sponsor
    let tiers: [SponsorTier]
    @ObservedObject var viewModel: SponsorsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var detail: SponsorDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isEditing = false
    @State private var isAddingContact = false
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if isLoading && detail == nil { ProgressView("Loading sponsor").frame(maxWidth: .infinity).padding(.top, 32) }
                else if let detail { SponsorSummary(detail: detail); contactsSection(detail.contacts) }
                // Outside the `detail` branch on purpose: this link only needs the
                // sponsor's id, which we already have, so a slow or failed
                // `sponsors:get` should not hide it.
                tasksLink
                if let errorMessage { Text(errorMessage).font(.system(size: 13)).foregroundStyle(NamosColor.warning) }
            }.padding(16)
        }
        .background(NamosColor.background).navigationTitle(sponsor.name)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Menu { Button("Edit sponsor") { isEditing = true }; Button("Delete sponsor", role: .destructive) { isDeleteConfirmationPresented = true } }
            label: { Label("Sponsor actions", systemImage: "ellipsis.circle") }
        }}
        .task { await loadDetail() }.refreshable { await loadDetail() }
        .sheet(isPresented: $isEditing) { SponsorEditSheet(sponsor: detail?.sponsor ?? sponsor, tiers: tiers, viewModel: viewModel) }
        .sheet(isPresented: $isAddingContact) { SponsorContactEditSheet(sponsorId: sponsor.id) { await loadDetail() } }
        .alert("Delete sponsor?", isPresented: $isDeleteConfirmationPresented) {
            Button("Delete", role: .destructive) { Task { await viewModel.remove(sponsor); dismiss() } }; Button("Cancel", role: .cancel) {}
        } message: { Text("This permanently deletes \(sponsor.name) and its contacts. Related tasks and submissions will be unlinked.") }
    }
    /// Their outstanding items, plus the way in to applying a task template — both
    /// backed by data and mutations that already existed with no mobile surface.
    @ViewBuilder private var tasksLink: some View {
        NavigationLink {
            PersonTasksView(eventId: sponsor.eventId, person: .sponsor(id: sponsor.id, name: sponsor.name))
        } label: {
            HStack {
                Text("Tasks").font(.system(size: 15, weight: .medium)).foregroundStyle(NamosColor.text)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(NamosColor.mutedText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NamosColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func contactsSection(_ contacts: [SponsorContact]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("Contacts").font(.system(size: 17, weight: .semibold)).foregroundStyle(NamosColor.text); Spacer()
                Button("Add contact") { isAddingContact = true }.font(.system(size: 14, weight: .semibold)) }
            if contacts.isEmpty { Text("No contacts yet.").font(.system(size: 14)).foregroundStyle(NamosColor.mutedText).padding(.vertical, 8) }
            else { ForEach(contacts) { SponsorContactRow(contact: $0) } }
        }
    }
    private func loadDetail() async {
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        do { detail = try await ConvexClient.shared.query("sponsors:get", args: ["sponsorId": sponsor.id]) }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct SponsorSummary: View {
    let detail: SponsorDetail
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(detail.status.capitalized).font(.system(size: 13, weight: .medium)).foregroundStyle(NamosColor.mutedText)
            if let tier = detail.tier?.name { Text(tier).font(.system(size: 15)).foregroundStyle(NamosColor.text) }
            if let website = detail.website, let url = URL(string: website.hasPrefix("http") ? website : "https://\(website)") { Link(website, destination: url).font(.system(size: 15)) }
            if let notes = detail.notes, !notes.isEmpty { Text(notes).font(.system(size: 15)).foregroundStyle(NamosColor.text) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(NamosColor.surface).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SponsorContactRow: View {
    let contact: SponsorContact
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack { Text(contact.name).font(.system(size: 15, weight: .medium)).foregroundStyle(NamosColor.text)
                if contact.isPrimary { Text("Primary").font(.system(size: 12)).foregroundStyle(NamosColor.mutedText) } }
            if let role = contact.role, !role.isEmpty { Text(role).font(.system(size: 13)).foregroundStyle(NamosColor.mutedText) }
            if let email = contact.email, !email.isEmpty { Text(email).font(.system(size: 13)).foregroundStyle(NamosColor.mutedText) }
            if let phone = contact.phone, !phone.isEmpty { Text(phone).font(.system(size: 13)).foregroundStyle(NamosColor.mutedText) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(NamosColor.surface).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
