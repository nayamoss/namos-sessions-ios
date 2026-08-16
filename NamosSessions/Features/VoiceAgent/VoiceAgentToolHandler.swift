import ElevenLabs
import Foundation

/// Executes the approved, on-device ElevenLabs client tools for a voice session.
/// Convex applies the same organizer authorization to these calls as it does to the
/// rest of the mobile app.
@MainActor
final class VoiceAgentToolHandler {
    private let eventId: ConvexId
    private let navigation: AppNavigationState

    init(eventId: ConvexId, navigation: AppNavigationState) {
        self.eventId = eventId
        self.navigation = navigation
    }

    func execute(_ toolCall: ClientToolCallEvent) async -> VoiceAgentToolResult {
        do {
            let parameters = try toolCall.getParameters()
            switch toolCall.toolName {
            case "navigate_to_screen":
                return try navigate(parameters: parameters)
            case "get_pending_tasks_count":
                return try await pendingTasksCount()
            case "get_submission_review_status":
                return try await submissionReviewStatus()
            case "create_task":
                return try await createTask(parameters: parameters)
            default:
                return .error("The client tool '\(toolCall.toolName)' is not available in this app.")
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }

    private func navigate(parameters: [String: Any]) throws -> VoiceAgentToolResult {
        guard let requestedScreen = stringParameter(["screen", "screen_name", "tab"], in: parameters),
              let tab = AppTab(voiceToolScreenName: requestedScreen) else {
            throw VoiceAgentToolError.invalidScreen
        }

        switch tab {
        case .checkIn:
            navigation.showMore(.checkIn)
        case .speakers:
            navigation.showMore(.speakers)
        case .reviews:
            navigation.showMore(.reviews)
        case .sponsors:
            navigation.showMore(.sponsors)
        case .notifications:
            navigation.showMore(.notifications)
        case .dashboard, .agent, .tasks, .agenda, .more:
            navigation.selectedTab = tab
        }
        return .success("Opened \(tab.voiceToolDisplayName).")
    }

    private func pendingTasksCount() async throws -> VoiceAgentToolResult {
        let tasks: [OrganizerTask] = try await ConvexClient.shared.query(
            "tasks:list", args: ["eventId": eventId]
        )
        let count = tasks.filter { $0.status == "pending" }.count
        return .success("There \(count == 1 ? "is" : "are") \(count) pending \(count == 1 ? "task" : "tasks").")
    }

    private func submissionReviewStatus() async throws -> VoiceAgentToolResult {
        let submissions: [Submission] = try await ConvexClient.shared.query(
            "submissions:list", args: ["eventId": eventId]
        )
        let counts = Dictionary(grouping: submissions, by: \.status).mapValues(\.count)
        let summary = SubmissionReviewStatus.allCases.map {
            "\(counts[$0.rawValue, default: 0]) \($0.spokenName)"
        }.joined(separator: ", ")
        return .success("Submission review status: \(summary).")
    }

    private func createTask(parameters: [String: Any]) async throws -> VoiceAgentToolResult {
        guard let title = stringParameter(["title"], in: parameters), !title.isEmpty else {
            throw VoiceAgentToolError.missingTaskTitle
        }

        let targetType = stringParameter(["targetType", "target_type"], in: parameters)
            .flatMap(TaskTargetType.init(rawValue:)) ?? .contact
        var args: [String: Any] = [
            "eventId": eventId,
            "title": title,
            "targetType": targetType.rawValue,
        ]
        for key in ["speakerId", "speaker_id", "submissionId", "submission_id", "sponsorId", "sponsor_id", "linkedFormId", "linked_form_id"] {
            if let value = parameters[key] as? String, !value.isEmpty {
                args[canonicalArgumentName(for: key)] = value
            }
        }
        if let dueDate = parameters["dueDate"] as? Double ?? parameters["due_date"] as? Double {
            args["dueDate"] = dueDate
        }

        let _: ConvexId = try await ConvexClient.shared.mutation("tasks:create", args: args)
        return .success("Created task '\(title)'.")
    }

    private func stringParameter(_ names: [String], in parameters: [String: Any]) -> String? {
        names.compactMap { parameters[$0] as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private func canonicalArgumentName(for key: String) -> String {
        switch key {
        case "speaker_id": "speakerId"
        case "submission_id": "submissionId"
        case "sponsor_id": "sponsorId"
        case "linked_form_id": "linkedFormId"
        default: key
        }
    }
}

struct VoiceAgentToolResult {
    let text: String
    let isError: Bool

    static func success(_ text: String) -> Self { .init(text: text, isError: false) }
    static func error(_ text: String) -> Self { .init(text: text, isError: true) }
}

private enum VoiceAgentToolError: LocalizedError {
    case invalidScreen
    case missingTaskTitle

    var errorDescription: String? {
        switch self {
        case .invalidScreen:
            "Choose one of dashboard, agent, tasks, agenda, check-in, speakers, reviews, sponsors, or notifications."
        case .missingTaskTitle:
            "A task title is required."
        }
    }
}

private enum TaskTargetType: String {
    case contact
    case group
    case submission
    case sponsor
}

private enum SubmissionReviewStatus: String, CaseIterable {
    case draft
    case pending
    case acceptQueue = "accept_queue"
    case accepted
    case declineQueue = "decline_queue"
    case declined
    case withdrawn

    var spokenName: String {
        switch self {
        case .acceptQueue: "awaiting acceptance"
        case .declineQueue: "awaiting decline"
        default: rawValue
        }
    }
}

private extension AppTab {
    init?(voiceToolScreenName: String) {
        switch voiceToolScreenName.lowercased().replacingOccurrences(of: "_", with: "-") {
        case "dashboard": self = .dashboard
        case "agent": self = .agent
        case "tasks", "task": self = .tasks
        case "agenda": self = .agenda
        case "check-in", "checkin": self = .checkIn
        case "speakers", "speaker": self = .speakers
        case "reviews", "review": self = .reviews
        case "sponsors", "sponsor": self = .sponsors
        case "notifications", "notification": self = .notifications
        default: return nil
        }
    }

    var voiceToolDisplayName: String {
        switch self {
        case .checkIn: "Check-in"
        default: String(describing: self).capitalized
        }
    }
}
