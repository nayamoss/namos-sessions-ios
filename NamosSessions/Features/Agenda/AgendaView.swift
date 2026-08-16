import SwiftUI

struct AgendaView: View {
    @StateObject private var viewModel: AgendaViewModel
    @State private var selectedItem: AgendaItem?

    init(eventId: ConvexId) {
        _viewModel = StateObject(wrappedValue: AgendaViewModel(eventId: eventId))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if let happeningNow = viewModel.happeningNow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Happening now")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(NamosColor.accent)
                        Text(happeningNow.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(NamosColor.text)
                        if let location = happeningNow.locationDetails, !location.isEmpty {
                            Text(location)
                                .font(.system(size: 13))
                                .foregroundStyle(NamosColor.mutedText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(NamosColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                ForEach(viewModel.items) { item in
                    Button { selectedItem = item } label: {
                        AgendaRow(item: item, isNow: item.id == viewModel.happeningNow?.id)
                    }
                    .buttonStyle(.plain)
                }
                if viewModel.items.isEmpty && !viewModel.isLoading {
                    Text("No agenda items yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(NamosColor.mutedText)
                        .padding(.top, 40)
                }
            }
            .padding(16)
        }
        .background(NamosColor.background)
        .navigationTitle("Agenda")
        .refreshable { await viewModel.refresh() }
        .task { viewModel.startSubscription() }
        .sheet(item: $selectedItem) { item in
            AgendaEditView(item: item, viewModel: viewModel)
        }
    }
}

private struct AgendaRow: View {
    let item: AgendaItem
    let isNow: Bool

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.timeFormatter.string(from: item.startDate))
                    .font(.system(size: 12, weight: .medium))
                Text(Self.timeFormatter.string(from: item.endDate))
                    .font(.system(size: 12))
                    .foregroundStyle(NamosColor.mutedText)
            }
            .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.system(size: 15, weight: .medium))
                if let location = item.locationDetails, !location.isEmpty {
                    Text(location).font(.system(size: 13)).foregroundStyle(NamosColor.mutedText)
                }
            }
            Spacer()
            if isNow {
                Text("NOW")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(NamosColor.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(NamosColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
