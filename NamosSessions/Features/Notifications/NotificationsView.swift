import SwiftUI

struct NotificationsView: View {
    @ObservedObject var viewModel: NotificationsViewModel
    @State private var selectedNotification: NamosNotification?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(NamosColor.warning)
                }
                ForEach(viewModel.notifications) { notification in
                    Button {
                        selectedNotification = notification
                        Task { await viewModel.markRead(notification) }
                    } label: {
                        NotificationRow(notification: notification)
                    }
                    .buttonStyle(.plain)
                }
                if viewModel.notifications.isEmpty && !viewModel.isLoading {
                    Text("No notifications yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(NamosColor.mutedText)
                        .padding(.top, 40)
                }
            }
            .padding(16)
        }
        .background(NamosColor.background)
        .navigationTitle("Notifications")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Mark all read") { Task { await viewModel.markAllRead() } }
                    .disabled(viewModel.unreadCount == 0)
            }
        }
        .refreshable { await viewModel.refresh() }
        .task { viewModel.startSubscription() }
        .sheet(item: $selectedNotification) { notification in
            NotificationDetailView(notification: notification)
        }
    }
}

private struct NotificationRow: View {
    let notification: NamosNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !notification.isRead {
                Circle().fill(NamosColor.accent).frame(width: 8, height: 8).padding(.top, 7)
            } else {
                Color.clear.frame(width: 8, height: 8).padding(.top, 7)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.system(size: 15, weight: notification.isRead ? .regular : .semibold))
                    .foregroundStyle(NamosColor.text)
                if let body = notification.body, !body.isEmpty {
                    Text(body).font(.system(size: 13)).foregroundStyle(NamosColor.mutedText).lineLimit(2)
                }
                Text(notification.createdDate, style: .relative)
                    .font(.system(size: 12))
                    .foregroundStyle(NamosColor.mutedText)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(NamosColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct NotificationDetailView: View {
    let notification: NamosNotification
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(notification.title).font(.system(size: 20, weight: .semibold)).foregroundStyle(NamosColor.text)
                    if let body = notification.body, !body.isEmpty {
                        Text(body).font(.system(size: 16)).foregroundStyle(NamosColor.text)
                    }
                    Text(notification.createdDate, style: .date)
                        .font(.system(size: 13)).foregroundStyle(NamosColor.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(NamosColor.background)
            .navigationTitle("Notification")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
