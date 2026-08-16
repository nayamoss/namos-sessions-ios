import SwiftUI

struct AgendaEditView: View {
    let item: AgendaItem
    @ObservedObject var viewModel: AgendaViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var roomId: ConvexId
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isPublished: Bool
    @State private var rooms: [NamosRoom] = []
    @State private var conflicts: [AgendaConflict] = []
    @State private var isLoadingRooms = false
    @State private var isCheckingConflicts = false
    @State private var isSaving = false
    @State private var localError: String?

    init(item: AgendaItem, viewModel: AgendaViewModel) {
        self.item = item
        self.viewModel = viewModel
        _title = State(initialValue: item.title)
        _roomId = State(initialValue: item.roomId)
        _startDate = State(initialValue: item.startDate)
        _endDate = State(initialValue: item.endDate)
        _isPublished = State(initialValue: item.isPublished)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    TextField("Title", text: $title)
                    if isLoadingRooms {
                        ProgressView("Loading rooms")
                    } else {
                        Picker("Room", selection: $roomId) {
                            ForEach(rooms) { room in
                                Text(room.name).tag(room.id)
                            }
                        }
                    }
                }
                Section("Time") {
                    DatePicker("Starts", selection: $startDate)
                    DatePicker("Ends", selection: $endDate)
                }
                Section("Visibility") {
                    Toggle("Published", isOn: $isPublished)
                }
                if let error = localError ?? viewModel.errorMessage {
                    Text(error).font(.system(size: 13)).foregroundStyle(NamosColor.warning)
                }
                if !conflicts.isEmpty {
                    Section("Schedule conflicts") {
                        Text("Review these conflicts before saving.")
                            .font(.system(size: 13)).foregroundStyle(NamosColor.warning)
                        ForEach(conflicts) { conflict in
                            Text(conflictDescription(conflict))
                                .font(.system(size: 14)).foregroundStyle(NamosColor.text)
                        }
                    }
                }
            }
            .navigationTitle("Edit session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(conflicts.isEmpty ? "Save" : "Save anyway") {
                        Task { await saveOrCheckConflicts() }
                    }
                    .disabled(!canSave || isCheckingConflicts || isSaving)
                }
            }
            .task { await loadRooms() }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && rooms.contains(where: { $0.id == roomId })
            && startDate < endDate
    }

    private var pendingItem: AgendaItem {
        AgendaItem(
            _id: item._id, eventId: item.eventId, title: title, roomId: roomId,
            trackId: item.trackId, startTime: startDate.timeIntervalSince1970 * 1000,
            endTime: endDate.timeIntervalSince1970 * 1000, speakerIds: item.speakerIds,
            videoUrl: item.videoUrl, isPublished: isPublished, locationDetails: item.locationDetails
        )
    }

    private func loadRooms() async {
        isLoadingRooms = true
        defer { isLoadingRooms = false }
        do {
            rooms = try await viewModel.loadRooms()
            if !rooms.contains(where: { $0.id == roomId }) { localError = "The current room is no longer available." }
        } catch {
            localError = error.localizedDescription
        }
    }

    private func saveOrCheckConflicts() async {
        localError = nil
        if conflicts.isEmpty {
            isCheckingConflicts = true
            defer { isCheckingConflicts = false }
            do {
                conflicts = try await viewModel.conflicts(for: item)
                if !conflicts.isEmpty { return }
            } catch {
                localError = error.localizedDescription
                return
            }
        }
        isSaving = true
        let saved = await viewModel.saveItem(pendingItem)
        isSaving = false
        if saved { dismiss() }
    }

    private func conflictDescription(_ conflict: AgendaConflict) -> String {
        let otherId = conflict.itemA == item.id ? conflict.itemB : conflict.itemA
        let reason: String
        switch conflict.reason {
        case "room_overlap": reason = "Room overlaps another session"
        case "speaker_overlap": reason = "A speaker overlaps another session"
        case "speaker_unavailable": reason = "A speaker is unavailable"
        case "track_overlap": reason = "Track overlaps another session"
        default: reason = "Schedule conflict"
        }
        return "\(reason) (session \(otherId))."
    }
}
