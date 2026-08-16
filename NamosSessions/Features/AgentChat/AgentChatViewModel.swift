import Foundation
import Combine

/// Drives one agent run at a time for the selected event, against the exact same
/// `agentRuns:create` / `agentRuns:respond` / `agentRuns:get` functions the webapp's
/// agent panel calls (convex/agentRuns.ts). Nothing here is mobile-specific business
/// logic — it's a thin voice-in/text-out wrapper around a run that already exists.
@MainActor
final class AgentChatViewModel: ObservableObject {
    @Published var events: [AgentRunEvent] = []
    @Published var run: AgentRun?
    @Published var proposals: [TaskProposal] = []
    @Published var isSending = false
    @Published var errorMessage: String?

    let eventId: ConvexId
    private var pollTask: Task<Void, Never>?
    private var subscriptionTask: Task<Void, Never>?

    init(eventId: ConvexId) {
        self.eventId = eventId
    }

    deinit {
        pollTask?.cancel()
        subscriptionTask?.cancel()
    }

    /// Sends a new objective (voice transcript or typed text) as a fresh run.
    func send(_ text: String) async {
        let objective = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !objective.isEmpty else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            if let run, run.isWaitingForReply {
                let _: EmptyResult = try await ConvexClient.shared.mutation("agentRuns:respond", args: [
                    "eventId": eventId,
                    "runId": run.id,
                    "message": objective,
                    "idempotencyKey": UUID().uuidString,
                ])
            } else {
                let result: CreateRunResult = try await ConvexClient.shared.mutation("agentRuns:create", args: [
                    "eventId": eventId,
                    "objective": objective,
                    "idempotencyKey": UUID().uuidString,
                ])
                startLiveUpdates(runId: result.runId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// ConvexMobile supplies a live WebSocket query. HTTP polling remains a graceful
    /// fallback when the deployment has not been configured for the mobile client.
    private func startLiveUpdates(runId: ConvexId) {
        guard let client = ConvexLiveClient.shared.client else {
            startPolling(runId: runId)
            return
        }
        subscriptionTask?.cancel()
        subscriptionTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await detail in client
                    .subscribe(to: "agentRuns:get", with: ["eventId": eventId, "runId": runId], yielding: AgentRunDetail.self)
                    .values {
                    guard !Task.isCancelled else { break }
                    self.run = detail.run
                    self.events = detail.events
                    self.proposals = detail.proposals
                }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func startPolling(runId: ConvexId) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let detail: AgentRunDetail = try await ConvexClient.shared.query("agentRuns:get", args: [
                        "eventId": self.eventId,
                        "runId": runId,
                    ])
                    self.run = detail.run
                    self.events = detail.events
                    self.proposals = detail.proposals
                    if !detail.run.isActive { break }
                } catch {
                    self.errorMessage = error.localizedDescription
                    break
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    func decide(on proposal: TaskProposal, approve: Bool) async {
        errorMessage = nil
        do {
            if approve {
                let _: ApprovalResult = try await ConvexClient.shared.mutation("agentRuns:approveTaskProposal", args: ["eventId": eventId, "proposalId": proposal.id, "expectedPayloadHash": proposal.payloadHash])
            } else {
                let _: EmptyResult = try await ConvexClient.shared.mutation("agentRuns:rejectProposal", args: ["eventId": eventId, "proposalId": proposal.id])
            }
        } catch { errorMessage = error.localizedDescription }
    }
}

/// Convex mutations that return nothing meaningful still return `null` — decode into
/// this rather than `Void`, which isn't `Decodable`.
private struct EmptyResult: Decodable {}
private struct ApprovalResult: Decodable { let createdTaskIds: [ConvexId] }
