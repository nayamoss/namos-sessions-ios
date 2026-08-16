import Combine
import ConvexMobile
import Foundation

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [NamosNotification] = []
    @Published var unreadCount = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var listSubscriptionTask: Task<Void, Never>?
    private var unreadSubscriptionTask: Task<Void, Never>?

    /// ConvexClient's HTTP fallback JSON-encodes args itself, so plain `Any` values work.
    private var httpPaginationArgs: [String: Any] {
        ["paginationOpts": ["numItems": 100, "cursor": NSNull()]]
    }

    /// ConvexMobile's live subscribe requires `ConvexEncodable` values — a nested
    /// dictionary must itself be typed `[String: ConvexEncodable?]` to conform (see
    /// convex-swift's Encoding.swift), which is a different static type than the `Any`
    /// dictionary the HTTP fallback above accepts.
    private var livePaginationArgs: [String: ConvexEncodable?] {
        ["paginationOpts": ["numItems": 100, "cursor": nil] as [String: ConvexEncodable?]]
    }

    deinit {
        listSubscriptionTask?.cancel()
        unreadSubscriptionTask?.cancel()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let page: ConvexPage<NamosNotification> = ConvexClient.shared.query("notifications:list", args: httpPaginationArgs)
            async let count: Int = ConvexClient.shared.query("notifications:unreadCount")
            notifications = try await page.page.sorted { $0.createdAt > $1.createdAt }
            unreadCount = try await count
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startSubscription() {
        guard let client = ConvexLiveClient.shared.client else {
            Task { await refresh() }
            return
        }
        listSubscriptionTask?.cancel()
        unreadSubscriptionTask?.cancel()
        listSubscriptionTask = Task { [weak self] in
            guard let self else { return }
            let updates = client
                .subscribe(to: "notifications:list", with: livePaginationArgs, yielding: ConvexPage<NamosNotification>.self)
                .replaceError(with: ConvexPage(page: [], isDone: true, continueCursor: nil))
                .values
            for await page in updates {
                guard !Task.isCancelled else { break }
                notifications = page.page.sorted { $0.createdAt > $1.createdAt }
            }
        }
        unreadSubscriptionTask = Task { [weak self] in
            guard let self else { return }
            let updates = client
                .subscribe(to: "notifications:unreadCount", with: [:], yielding: Int.self)
                .replaceError(with: 0)
                .values
            for await count in updates {
                guard !Task.isCancelled else { break }
                unreadCount = count
            }
        }
    }

    func markRead(_ notification: NamosNotification) async {
        guard !notification.isRead else { return }
        updateReadState(for: notification.id, readAt: Date().timeIntervalSince1970 * 1000)
        do {
            let _: EmptyResult = try await ConvexClient.shared.mutation("notifications:markRead", args: ["notificationId": notification.id])
        } catch {
            errorMessage = error.localizedDescription
            await refresh()
        }
    }

    func markAllRead() async {
        let now = Date().timeIntervalSince1970 * 1000
        let unreadIds = notifications.filter { !$0.isRead }.map(\.id)
        unreadIds.forEach { updateReadState(for: $0, readAt: now) }
        do {
            let _: EmptyResult = try await ConvexClient.shared.mutation("notifications:markAllRead")
        } catch {
            errorMessage = error.localizedDescription
            await refresh()
        }
    }

    private func updateReadState(for id: ConvexId, readAt: Double) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        let current = notifications[index]
        guard !current.isRead else { return }
        notifications[index] = NamosNotification(
            _id: current._id, eventId: current.eventId, recipientUserId: current.recipientUserId,
            kind: current.kind, title: current.title, body: current.body, linkPath: current.linkPath,
            relatedId: current.relatedId, readAt: readAt, emailedAt: current.emailedAt,
            createdAt: current.createdAt, _creationTime: current._creationTime
        )
        unreadCount = max(0, unreadCount - 1)
    }
}

private struct EmptyResult: Decodable {}
