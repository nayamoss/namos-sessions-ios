import SwiftUI

/// Applies an existing `task_templates` row to a sponsor or a submission.
///
/// The backend for this has existed the whole time — `taskTemplates:list`,
/// `applyToSubmission` and `applyToSponsor` — with no iOS surface at all, so an
/// organizer setting up onboarding on their phone had to retype every task by hand.
/// This adds the missing surface and no new backend.
struct TaskTemplatePickerSheet: View {
    enum Target: Hashable {
        case sponsor(id: ConvexId)
        case submission(id: ConvexId)

        var mutationName: String {
            switch self {
            case .sponsor: return "taskTemplates:applyToSponsor"
            case .submission: return "taskTemplates:applyToSubmission"
            }
        }

        var idArgumentName: String {
            switch self {
            case .sponsor: return "sponsorId"
            case .submission: return "submissionId"
            }
        }

        var id: ConvexId {
            switch self {
            case .sponsor(let id), .submission(let id): return id
            }
        }
    }

    let eventId: ConvexId
    let target: Target
    /// Lets the presenting screen reload once tasks have actually been created.
    let onApplied: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var templates: [TaskTemplate] = []
    @State private var isLoading = true
    @State private var applyingId: ConvexId?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(NamosColor.warning)
                    }

                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if templates.isEmpty {
                        Text("No task templates for this event yet. Create one on the web dashboard.")
                            .font(.system(size: 14))
                            .foregroundStyle(NamosColor.mutedText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        ForEach(templates) { template in
                            Button {
                                Task { await apply(template) }
                            } label: {
                                TemplateRow(template: template, isApplying: applyingId == template.id)
                            }
                            .buttonStyle(.plain)
                            .disabled(applyingId != nil)
                        }
                    }
                }
                .padding(16)
            }
            .background(NamosColor.background)
            .navigationTitle("Apply a template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            templates = try await ConvexClient.shared.query("taskTemplates:list", args: ["eventId": eventId])
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ template: TaskTemplate) async {
        applyingId = template.id
        defer { applyingId = nil }
        do {
            let _: EmptyTemplateResult = try await ConvexClient.shared.mutation(
                target.mutationName,
                args: ["templateId": template.id, target.idArgumentName: target.id]
            )
            await onApplied()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EmptyTemplateResult: Decodable {}

private struct TemplateRow: View {
    let template: TaskTemplate
    let isApplying: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(NamosColor.text)
                if let description = template.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(NamosColor.mutedText)
                }
                Text(template.itemCountLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(NamosColor.mutedText)
            }
            Spacer(minLength: 0)
            if isApplying { ProgressView() }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NamosColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
