import Foundation

/// Convex document ids are opaque strings on the wire — same type the webapp treats them
/// as in JSON. No client-side validation of shape; the server is the source of truth.
typealias ConvexId = String

/// Convex paginated queries return a page plus pagination state rather than a bare array.
struct ConvexPage<Element: Decodable>: Decodable {
    let page: [Element]
    let isDone: Bool
    let continueCursor: String?
}

// MARK: - events (convex/schema.ts)

struct NamosEvent: Decodable, Identifiable, Hashable {
    let _id: ConvexId
    let name: String
    let slug: String
    let timezone: String
    let startDate: Double
    let endDate: Double
    let status: String

    var id: ConvexId { _id }
}

// MARK: - onboarding_tasks (convex/tasks.ts)

struct OrganizerTask: Decodable, Identifiable, Hashable {
    let _id: ConvexId
    let eventId: ConvexId
    let title: String
    let description: String?
    let status: String // "pending" | "in_progress" | "completed"
    let targetType: String
    let dueDate: Double?
    let source: String
    /// Already on every `onboarding_tasks` row; the mobile client just never read them,
    /// which is why there was no way to see one person's outstanding items.
    let speakerId: ConvexId?
    let sponsorId: ConvexId?
    let submissionId: ConvexId?

    var id: ConvexId { _id }

    var isDone: Bool { status == "completed" }
}

// MARK: - task_templates (convex/taskTemplates.ts)

/// One entry in a template. Decoded for display only — the server does the expansion
/// in `applyToSubmission`/`applyToSponsor`.
struct TaskTemplateItem: Decodable, Hashable {
    let title: String
    let description: String?
    let targetType: String?
    let dueDateOffsetDays: Double?
}

struct TaskTemplate: Decodable, Identifiable, Hashable {
    let _id: ConvexId
    let eventId: ConvexId
    let name: String
    let description: String?
    let items: [TaskTemplateItem]

    var id: ConvexId { _id }
    var itemCountLabel: String { items.count == 1 ? "1 task" : "\(items.count) tasks" }
}

// MARK: - speakers (convex/speakers.ts)

/// The organizer-facing mobile workflows decode only the speaker fields they display
/// or update. Profile and portal-only fields remain outside this surface.
struct Speaker: Decodable, Identifiable, Hashable {
    let _id: ConvexId
    let eventId: ConvexId
    let firstName: String
    let lastName: String
    let email: String
    let confirmationStatus: String?
    let checkedInAt: Double?
    let checkedInByUserId: String?

    var id: ConvexId { _id }
    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
    var isCheckedIn: Bool { checkedInAt != nil }
    var confirmationStatusLabel: String {
        switch confirmationStatus {
        case "confirmed": "Confirmed"
        case "declined": "Declined"
        default: "Awaiting"
        }
    }
}

// MARK: - agenda_items (convex/agenda.ts)

struct AgendaItem: Decodable, Identifiable, Hashable {
    let _id: ConvexId
    let eventId: ConvexId
    let title: String
    let roomId: ConvexId
    let trackId: ConvexId?
    let startTime: Double
    let endTime: Double
    let speakerIds: [ConvexId]
    let videoUrl: String?
    let isPublished: Bool
    let locationDetails: String?

    var id: ConvexId { _id }

    var startDate: Date { Date(timeIntervalSince1970: startTime / 1000) }
    var endDate: Date { Date(timeIntervalSince1970: endTime / 1000) }
}

struct NamosRoom: Decodable, Identifiable, Hashable {
    let _id: ConvexId
    let eventId: ConvexId
    let name: String
    let capacity: Double?
    let sortOrder: Double

    var id: ConvexId { _id }
}

struct AgendaConflict: Decodable, Identifiable, Hashable {
    let itemA: ConvexId
    let itemB: ConvexId
    let reason: String
    let speakerId: ConvexId?

    var id: String { "\(itemA)-\(itemB)-\(reason)-\(speakerId ?? "")" }
}

// MARK: - notifications (convex/notifications.ts)

struct NamosNotification: Decodable, Identifiable, Hashable {
    let _id: ConvexId
    let eventId: ConvexId
    let recipientUserId: String
    let kind: String
    let title: String
    let body: String?
    let linkPath: String?
    let relatedId: String?
    let readAt: Double?
    let emailedAt: Double?
    let createdAt: Double
    let _creationTime: Double

    var id: ConvexId { _id }
    var isRead: Bool { readAt != nil }
    var createdDate: Date { Date(timeIntervalSince1970: createdAt / 1000) }
}

// MARK: - agent_runs / agent_run_events (convex/agentRuns.ts)

struct AgentRun: Decodable, Identifiable, Hashable {
    let _id: ConvexId
    let eventId: ConvexId
    let objective: String
    let status: String // queued | running | needs_input | needs_approval | completed | failed | cancelled
    let finalSummary: String?
    let error: String?
    let createdAt: Double

    var id: ConvexId { _id }

    var isWaitingForReply: Bool { status == "needs_input" }
    var isActive: Bool { ["queued", "running", "needs_input", "needs_approval"].contains(status) }
}

struct AgentRunEvent: Decodable, Identifiable, Hashable {
    let _id: ConvexId
    let runId: ConvexId
    let sequence: Double
    let type: String // user_message | assistant_message | progress | tool_call | tool_result | clarification | proposal | approval | error
    let message: String
    let createdAt: Double

    var id: ConvexId { _id }

    var isFromUser: Bool { type == "user_message" }
}

struct AgentRunDetail: Decodable {
    let run: AgentRun
    let events: [AgentRunEvent]
    let proposals: [TaskProposal]
}

struct TaskProposal: Decodable, Identifiable, Hashable {
    struct ProposedTask: Decodable, Hashable { let title: String; let targetType: String; let reason: String }
    let _id: ConvexId
    let payloadHash: String
    let summary: String
    let status: String
    let tasks: [ProposedTask]
    var id: ConvexId { _id }
}

struct CreateRunResult: Decodable {
    let runId: ConvexId
}

// MARK: - evaluations (convex/evaluations.ts)

struct Criterion: Decodable, Hashable, Identifiable {
    let id: String
    let label: String
    let type: String // "number" | "text"
    let max: Double?
    let weight: Double?
    let required: Bool
}

struct CriterionScore: Decodable, Hashable {
    let criterionId: String
    let value: Double?
    let text: String?
}

struct Review: Decodable, Hashable {
    let id: ConvexId
    let score: Double?
    let comments: String?
    let criteriaScores: [CriterionScore]?
}

struct ReviewerQueueRow: Decodable, Identifiable, Hashable {
    let assignmentId: ConvexId
    let eventId: ConvexId
    let submissionId: ConvexId
    let submissionTitle: String
    let submissionAnswers: [String: String]
    let speakerNames: [String]?
    let round: Double
    let planName: String
    let scoringScaleMax: Double
    let anonymized: Bool
    let criteria: [Criterion]?
    let review: Review?

    var id: ConvexId { assignmentId }
    var isComplete: Bool { review != nil }
}

// MARK: - submissions (convex/submissions.ts)

struct Submission: Decodable, Identifiable, Hashable {
    let _id: ConvexId
    let eventId: ConvexId
    let formId: ConvexId
    let speakerId: ConvexId?
    let title: String
    let status: String
    let answers: [String: JSONValue]
    let submittedAt: Double?
    let createdAt: Double
    let updatedAt: Double

    var id: ConvexId { _id }
}

// MARK: - sponsors (convex/sponsors.ts / sponsorTiers.ts / sponsorContacts.ts)

struct SponsorTier: Decodable, Identifiable, Hashable {
    let _id: ConvexId
    let eventId: ConvexId
    let name: String
    let sortOrder: Double
    let color: String?
    let benefitsDescription: String?
    let sponsorCount: Int?
    var id: ConvexId { _id }
}

struct SponsorContact: Decodable, Identifiable, Hashable {
    let _id: ConvexId
    let eventId: ConvexId
    let sponsorId: ConvexId
    let name: String
    let email: String?
    let phone: String?
    let role: String?
    let isPrimary: Bool
    var id: ConvexId { _id }
}

struct Sponsor: Decodable, Identifiable, Hashable {
    let _id: ConvexId
    let eventId: ConvexId
    let tierId: ConvexId?
    let name: String
    let status: String
    let website: String?
    let notes: String?
    let tier: SponsorTier?
    let primaryContact: SponsorContact?
    let openTaskCount: Int?
    var id: ConvexId { _id }
}

struct SponsorDetail: Decodable {
    let _id: ConvexId
    let eventId: ConvexId
    let tierId: ConvexId?
    let name: String
    let status: String
    let website: String?
    let notes: String?
    let tier: SponsorTier?
    let contacts: [SponsorContact]
    let openTaskCount: Int

    var sponsor: Sponsor {
        Sponsor(_id: _id, eventId: eventId, tierId: tierId, name: name, status: status,
                website: website, notes: notes, tier: tier, primaryContact: nil,
                openTaskCount: openTaskCount)
    }
}

enum JSONValue: Decodable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    var displayValue: String {
        switch self {
        case .string(let value): return value
        case .number(let value): return value.formatted()
        case .bool(let value): return value ? "Yes" : "No"
        case .null: return "—"
        case .array(let values): return values.map(\.displayValue).joined(separator: ", ")
        case .object(let values):
            return values.keys.sorted().map { "\($0): \(values[$0]?.displayValue ?? "—")" }.joined(separator: "; ")
        }
    }
}
