import SwiftUI

struct SponsorsView: View {
    @StateObject private var viewModel: SponsorsViewModel
    @State private var isCreating = false
    @State private var sponsorToDelete: Sponsor?

    init(eventId: ConvexId) { _viewModel = StateObject(wrappedValue: SponsorsViewModel(eventId: eventId)) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(.system(size: 13)).foregroundStyle(NamosColor.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(viewModel.sponsors) { sponsor in
                    // Destination-based, not value-based: this screen lives inside
                    // MoreView's NavigationStack, whose path is typed [MoreDestination].
                    // A typed path only accepts values of its own type, so
                    // NavigationLink(value: sponsor) silently did nothing and sponsor
                    // detail was unreachable from the More tab entirely.
                    NavigationLink {
                        SponsorDetailView(sponsor: sponsor, tiers: viewModel.tiers, viewModel: viewModel)
                    } label: {
                        SponsorRow(sponsor: sponsor)
                    }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { sponsorToDelete = sponsor } label: {
                                Label("Delete sponsor", systemImage: "trash")
                            }
                        }
                }
                if viewModel.sponsors.isEmpty && !viewModel.isLoading {
                    Text("No sponsors for this event yet.").font(.system(size: 14))
                        .foregroundStyle(NamosColor.mutedText).padding(.top, 40)
                }
            }.padding(16)
        }
        .background(NamosColor.background)
        .navigationTitle("Sponsors")
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { isCreating = true } label: { Label("Add sponsor", systemImage: "plus") }
        }}
        .refreshable { await viewModel.refresh() }
        .task { viewModel.startSubscription() }
        .sheet(isPresented: $isCreating) { SponsorEditSheet(sponsor: nil, tiers: viewModel.tiers, viewModel: viewModel) }
        .alert("Delete sponsor?", isPresented: Binding(get: { sponsorToDelete != nil }, set: { if !$0 { sponsorToDelete = nil } }), presenting: sponsorToDelete) { sponsor in
            Button("Delete", role: .destructive) { Task { await viewModel.remove(sponsor) } }
            Button("Cancel", role: .cancel) {}
        } message: { sponsor in
            Text("This permanently deletes \(sponsor.name) and its contacts. Related tasks and submissions will be unlinked.")
        }
    }
}

private struct SponsorRow: View {
    let sponsor: Sponsor
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sponsor.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(NamosColor.text)
                Text(detailText).font(.system(size: 13)).foregroundStyle(NamosColor.mutedText)
            }
            Spacer(minLength: 8)
            Text(sponsor.status.capitalized).font(.system(size: 12, weight: .medium)).foregroundStyle(NamosColor.mutedText)
        }
        .padding(14).background(NamosColor.surface).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    private var detailText: String { sponsor.tier?.name ?? sponsor.primaryContact?.name ?? "No tier assigned" }
}
