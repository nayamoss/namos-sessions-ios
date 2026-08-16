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
    /// An organizer with more than one event cannot otherwise tell which one these
    /// numbers belong to — the tiles are all bare counts.
    let eventName: String
    let onSelect: (DashboardDestination) -> Void

    init(eventId: ConvexId, eventName: String, onSelect: @escaping (DashboardDestination) -> Void) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(eventId: eventId))
        self.eventName = eventName
        self.onSelect = onSelect
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ScrollView {
            // Event names are long ("AI.Engineer Sandbox Event…") and a large nav title
            // truncates them to uselessness. As a subtitle it wraps and stays legible.
            Text(eventName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(NamosColor.mutedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .accessibilityLabel("Event: \(eventName)")

            LazyVGrid(columns: columns, spacing: 10) {
                DashboardTile(title: "Notifications", state: viewModel.notificationsTile) {
                    onSelect(.notifications)
                }
                DashboardTile(title: "Tasks", state: viewModel.tasksTile) {
                    onSelect(.tasks)
                }
                DashboardTile(
                    title: viewModel.happeningNow == nil ? "Next" : "Now",
                    state: viewModel.agendaTile
                ) {
                    onSelect(.agenda)
                }
                DashboardTile(title: "Check-in", state: viewModel.checkInTile) {
                    onSelect(.checkIn)
                }
                if viewModel.reviewQueueCount > 0 {
                    DashboardTile(title: "Reviews", state: .count(viewModel.reviewQueueCount)) {
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

/// What a tile has to say. Keeping this a value rather than a preformatted string is
/// what lets the tile render "nothing yet" differently from a real number — the whole
/// point of the fix: `0`, `—` and `0 of 0` all looked like data when they were not.
enum DashboardTileState {
    case loading
    case count(Int)
    case text(String)
    /// Nothing to show yet, and that is the true state — not a zero standing in for it.
    case empty(String)
}

private struct DashboardTile: View {
    let title: String
    let state: DashboardTileState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NamosColor.mutedText)
                valueView
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .padding(16)
            .background(NamosColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(accessibilityValue)")
    }

    @ViewBuilder
    private var valueView: some View {
        switch state {
        case .loading:
            // A muted placeholder rather than "0" — a zero that later becomes 12 reads
            // as data that changed, not as a value that had not arrived.
            Text("…")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(NamosColor.mutedText)
        case .count(let value):
            Text("\(value)")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(NamosColor.text)
        case .text(let value):
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(NamosColor.text)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
        case .empty(let message):
            // Deliberately smaller and muted: an empty state is not a headline number.
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(NamosColor.mutedText)
                .lineLimit(3)
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .loading: return "loading"
        case .count(let value): return "\(value)"
        case .text(let value): return value
        case .empty(let message): return message
        }
    }
}

