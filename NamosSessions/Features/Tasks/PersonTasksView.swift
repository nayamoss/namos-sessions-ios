import SwiftUI

/// "What does this person still owe me?" — the question the flat Tasks list could not
/// answer. `onboarding_tasks` has always carried `speakerId`/`sponsorId`; this screen
/// is the first place iOS reads them.
///
/// Speakers use the server-side filter (`tasks:list` takes an optional `speakerId` and
/// queries `by_speaker`). Sponsors now use the equivalent `sponsorId` argument added to
/// `tasks:list` (queries `by_sponsor`), so both paths filter server-side.
struct PersonTasksView: View {
    enum Person: Hashable {
        case speaker(id: ConvexId, name: String)
        case sponsor(id: ConvexId, name: String)

        var name: String {
            switch self {
            case .speaker(_, let name), .sponsor(_, let name): return name
            }
        }
    }

    let eventId: ConvexId
    let person: Person

    @State private var tasks: [OrganizerTask] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isApplyingTemplate = false

    private var outstanding: [OrganizerTask] { tasks.filter { !$0.isDone } }
    private var done: [OrganizerTask] { tasks.filter(\.isDone) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(NamosColor.warning)
                }

                if isLoading && tasks.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if tasks.isEmpty {
                    Text("Nothing assigned to \(person.name) yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(NamosColor.mutedText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    if !outstanding.isEmpty {
                        sectionHeader("Outstanding")
                        ForEach(outstanding) { task in
                            PersonTaskRow(task: task) { await toggle(task) }
                        }
                    }
                    if !done.isEmpty {
                        sectionHeader("Done")
                        ForEach(done) { task in
                            PersonTaskRow(task: task) { await toggle(task) }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(NamosColor.background)
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Applying a template is only wired for sponsors: the server's other entry
            // point, applyToSubmission, keys off a submission rather than a speaker.
            if case .sponsor = person {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Use template") { isApplyingTemplate = true }
                        .font(.system(size: 15, weight: .medium))
                }
            }
        }
        .sheet(isPresented: $isApplyingTemplate) {
            if case .sponsor(let sponsorId, _) = person {
                TaskTemplatePickerSheet(eventId: eventId, target: .sponsor(id: sponsorId)) {
                    await load()
                }
                .presentationDetents([.medium, .large])
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(NamosColor.mutedText)
            .padding(.top, 6)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            switch person {
            case .speaker(let speakerId, _):
                tasks = try await ConvexClient.shared.query(
                    "tasks:list",
                    args: ["eventId": eventId, "speakerId": speakerId]
                )
            case .sponsor(let sponsorId, _):
                tasks = try await ConvexClient.shared.query(
                    "tasks:list",
                    args: ["eventId": eventId, "sponsorId": sponsorId]
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggle(_ task: OrganizerTask) async {
        do {
            let _: EmptyTaskResult = try await ConvexClient.shared.mutation(
                "tasks:setStatus",
                args: ["id": task.id, "status": task.isDone ? "pending" : "completed"]
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EmptyTaskResult: Decodable {}

private struct PersonTaskRow: View {
    let task: OrganizerTask
    let onToggle: () async -> Void

    var body: some View {
        Button {
            Task { await onToggle() }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(task.isDone ? NamosColor.accent : NamosColor.mutedText)
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(NamosColor.text)
                        .strikethrough(task.isDone)
                        .multilineTextAlignment(.leading)
                    if let description = task.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundStyle(NamosColor.mutedText)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NamosColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
