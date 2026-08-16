import SwiftUI

struct TasksView: View {
    @StateObject private var viewModel: TasksViewModel
    @State private var isCreatingTask = false

    init(eventId: ConvexId) {
        _viewModel = StateObject(wrappedValue: TasksViewModel(eventId: eventId))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                Button {
                    isCreatingTask = true
                } label: {
                    Label("Add task", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .foregroundStyle(.white)
                .background(NamosColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                ForEach(viewModel.tasks) { task in
                    TaskRow(task: task) {
                        Task { await viewModel.toggleComplete(task) }
                    }
                }
                if viewModel.tasks.isEmpty && !viewModel.isLoading {
                    Text("No tasks yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(NamosColor.mutedText)
                        .padding(.top, 40)
                }
            }
            .padding(16)
        }
        .background(NamosColor.background)
        .navigationTitle("Tasks")
        .refreshable { await viewModel.refresh() }
        .task { viewModel.startSubscription() }
        .sheet(isPresented: $isCreatingTask) {
            // A two-field form does not need a full-height sheet; it left a large dead
            // void under the form.
            CreateTaskSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }
}

private struct CreateTaskSheet: View {
    @ObservedObject var viewModel: TasksViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var targetType = "contact"
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What needs to happen?", text: $title, axis: .vertical)
                        .lineLimit(2...4)
                }
                // "FOR / Target" read as though it wanted a specific person. It does
                // not — it sets `onboarding_tasks.targetType`, i.e. what kind of thing
                // the task is about. Labelled as the question it actually answers.
                Section {
                    Picker("Kind of task", selection: $targetType) {
                        Text("Contact").tag("contact")
                        Text("Group").tag("group")
                        Text("Submission").tag("submission")
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("What is this task about?")
                } footer: {
                    Text("Who it belongs to is set from a speaker or sponsor once the task exists.")
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).foregroundStyle(NamosColor.warning)
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            isSaving = true
                            if await viewModel.createTask(title: title, targetType: targetType) {
                                dismiss()
                            }
                            isSaving = false
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }
}

private struct TaskRow: View {
    let task: OrganizerTask
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(task.isDone ? NamosColor.accent : NamosColor.mutedText)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 15))
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? NamosColor.mutedText : NamosColor.text)
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(NamosColor.mutedText)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(NamosColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
