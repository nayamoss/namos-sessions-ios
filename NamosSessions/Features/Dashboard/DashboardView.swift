import SwiftUI

enum DashboardDestination {
    case notifications
    case tasks
    case agenda
    case reviews
    case checkIn
}

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    let onSelect: (DashboardDestination) -> Void

    init(eventId: ConvexId, onSelect: @escaping (DashboardDestination) -> Void) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(eventId: eventId))
        self.onSelect = onSelect
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                DashboardTile(title: "Notifications", value: "\(viewModel.unreadNotifications)") {
                    onSelect(.notifications)
                }
                DashboardTile(title: "Tasks", value: "\(viewModel.pendingTasks)") {
                    onSelect(.tasks)
                }
                DashboardTile(
                    title: viewModel.happeningNow == nil ? "Next" : "Now",
                    value: viewModel.currentOrNextAgendaItem?.title ?? "—"
                ) {
                    onSelect(.agenda)
                }
                DashboardTile(title: "Check-in", value: "\(viewModel.checkedInSpeakers) of \(viewModel.speakerCount)") {
                    onSelect(.checkIn)
                }
                if viewModel.reviewQueueCount > 0 {
                    DashboardTile(title: "Reviews", value: "\(viewModel.reviewQueueCount)") {
                        onSelect(.reviews)
                    }
                }
            }
            .padding(16)
        }
        .background(NamosColor.background)
        .navigationTitle("Dashboard")
        .refreshable { await viewModel.refresh() }
        .task { viewModel.startSubscriptions() }
    }
}

private struct DashboardTile: View {
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NamosColor.mutedText)
                Text(value)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(NamosColor.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .padding(16)
            .background(NamosColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(value)")
    }
}
