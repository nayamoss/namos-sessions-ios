# Plan

Work top to bottom. Backend for this pair needs zero changes (confirmed by reading
`convex/notifications.ts` and `convex/agenda.ts` directly — `list`, `unreadCount`,
`markRead`, `markAllRead`, `save`, `detectConflicts` all exist with the signatures
below). Rebuild + relaunch-in-Simulator after each task.

**Confirmed real signatures (do not let Codex invent different ones):**
- `notifications:list` — query, args `{ paginationOpts: PaginationOptions }` (Convex's
  standard pagination — NOT a plain array like tasks/agenda). Returns
  `{ page: Notification[], isDone: boolean, continueCursor: string }`, scoped
  implicitly to the caller's identity (`recipientUserId`), no `eventId` arg.
- `notifications:unreadCount` — query, no args, returns `number`. Also caller-scoped,
  not event-scoped.
- `notifications:markRead` — mutation, args `{ notificationId: Id<"notifications"> }`.
- `notifications:markAllRead` — mutation, no args.
- Notification fields: `_id`, `eventId`, `recipientUserId`, `kind` (string union),
  `title`, `body?`, `linkPath?`, `relatedId?`, `readAt?`, `emailedAt?`, `createdAt`,
  `_creationTime`.
- `agenda:list` — query, args `{ eventId }`, returns `AgendaItem[]` (already used by
  `AgendaViewModel`).
- `agenda:save` — mutation, args `{ id?: Id<"agenda_items">, eventId, title, roomId,
  trackId?, startTime, endTime, speakerIds: Id<"speakers">[], videoUrl?,
  locationDetails?, isPublished }`. `speakerIds` is required (not optional) — pass the
  existing item's current `speakerIds` back unchanged since speaker reassignment is out
  of scope for v1's edit sheet.
- `agenda:detectConflicts` — query, args `{ eventId }`, returns the WHOLE event's
  conflict list (not scoped to one item) — the client must filter for rows involving
  the item being edited (`itemA === id || itemB === id`) after fetching.
- `events:listRooms` — query, args `{ eventId }`, returns `Room[]` (`_id`, `eventId`,
  `name`, `capacity?`, `sortOrder`).

- [x] **1. Notification model.** Add `NamosNotification` to
      `NamosSessions/Models/ConvexModels.swift` matching the fields above. Add a
      `ConvexPage<T>` (or similarly named) generic decodable wrapper for
      `{ page, isDone, continueCursor }` since this is the first paginated query the app
      consumes — check `ConvexClient`/`ConvexLiveClient` don't already have one before
      adding a new type.

- [x] **2. Notifications tab — ViewModel + View.** New
      `NamosSessions/Features/Notifications/NotificationsViewModel.swift` and
      `NotificationsView.swift`, same shape as `TasksViewModel`/`AgendaViewModel`
      (`refresh()`, `startSubscription()` via `ConvexLiveClient`, `@Published` list +
      `unreadCount`, `isLoading`, `errorMessage`). List view: one row per notification
      (title, body if present, relative timestamp, unread dot), sorted `createdAt` desc,
      "Mark all read" nav bar button, `.refreshable`, empty state "No notifications yet."
      matching TasksView/AgendaView's empty-state tone. Tap a row → call `markRead`, then
      show a detail sheet with the full title/body (no deep-linking in v1, per
      requirements.md).

- [x] **3. Wire the 4th tab.** Add "Notifications" tab to `ContentView.swift`'s
      `TabView`, bell icon (`bell` / `bell.badge` SF Symbol), badge showing
      `unreadCount` when > 0 — same tab pattern as Agent/Tasks/Agenda.

- [x] **4. Agenda edit sheet.** In `AgendaView.swift`, make each `AgendaRow` tappable
      to open an edit sheet (new `AgendaEditView.swift` + a save method on
      `AgendaViewModel`, e.g. `saveItem(...)`). Fields: title (text), room (picker
      populated from `events:listRooms`), start/end time (date pickers), published
      toggle. Track assignment, speaker reassignment, video URL, and location free-text
      are deliberately excluded from this sheet per requirements.md — preserve the
      item's existing `trackId`/`speakerIds`/`videoUrl`/`locationDetails` unchanged when
      calling `agenda:save`.

- [x] **5. Conflict check before save.** Before calling `agenda:save`, call
      `agenda:detectConflicts`, filter for conflicts involving this item's id, and if
      any exist show them inline in the sheet (reason + which other item) requiring the
      organizer to tap "Save anyway" or "Cancel" — never save silently over a conflict.

- [x] **6. Optimistic save + rollback.** Save flow updates `AgendaViewModel.items`
      optimistically (same pattern as `TasksViewModel.toggleComplete`), rolls back via
      `refresh()` on mutation failure, surfaces `errorMessage` the same way existing
      screens do.

## After each task

1. `xcodegen generate` (only if `project.yml` changed — new Swift files under the
   existing source dir do not require this, but run it anyway if unsure).
2. `xcodebuild build -project NamosSessions.xcodeproj -scheme NamosSessions -destination 'platform=iOS Simulator,id=76A049CC-DF8A-449A-9794-CACD2AECBC1F' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES` — must show BUILD SUCCEEDED.
3. Install + launch in the simulator, confirm no `Fatal error` in console output.
4. Screenshot the new/changed screens, check they match NamosColor/NamosDesignSystem
   (no borders, no shadows, off-white surfaces).
5. Check off the task in this file.

## Final report

List which tasks were completed, which were skipped and why, and the exact
`xcodebuild`/simulator commands used to verify each one — don't just say "it builds."
