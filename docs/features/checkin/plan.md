# Plan

Backend first (webapp repo), then iOS. Rebuild + relaunch-in-Simulator after each iOS
task. Schema is pre-approved (see requirements.md's "Decision (approved)" section) —
do not re-litigate the design, just build it.

## Backend (namos-sessions-webapp — Convex)

- [x] **B1. Schema.** Add to the `speakers` table in `convex/schema.ts`:
      `checkedInAt: v.optional(v.number())`, `checkedInByUserId: v.optional(v.string())`,
      plus `.index("by_event_checkedIn", ["eventId", "checkedInAt"])`. Match the style of
      the existing `device_tokens` table addition (see `git show 70185b2` in this repo
      for the exact technique/format used for a prior additive schema change — same
      approach: comment above the field explaining intent, minimal diff, no unrelated
      changes to the file).

- [x] **B2. Mutations.** Add `checkIn(speakerId)` and `undoCheckIn(speakerId)` — read
      `convex/speakers.ts` and `convex/functions.ts` first for the real
      `assertEventOrganizerAccess` signature (it takes `(ctx, eventId)`, so these
      mutations need an `eventId` arg too, matching `setConfirmationStatus`'s pattern
      in the same file). Put them in `convex/speakers.ts` (small, and keeps check-in
      near the rest of the speaker-scoped mutations — no new file needed, this is the
      "your call" from requirements.md resolved in favor of the existing file since
      `speakers.ts` already holds several single-purpose mutations at similar size).
      `checkIn` sets `checkedInAt: Date.now()`, `checkedInByUserId: identity.subject`.
      `undoCheckIn` clears both to `undefined`. Both validate `speaker.eventId ===
      args.eventId` like `setConfirmationStatus` does.

- [x] **B3. Verify.** `npm run typecheck` (or the repo's actual typecheck script — check
      `package.json`) must pass. Do NOT run this against a live Convex deployment unless
      explicitly told to — schema changes to a live deployment need a deploy step this
      task does not include.

- [x] **B4. Isolate + commit (human-supervised, not Codex).** Codex only writes the
      diff and leaves it uncommitted in the working tree. The supervising agent then
      creates an isolated worktree (`git worktree add /tmp/<name> -b feature/checkin`),
      applies ONLY the schema.ts + speakers.ts diff there (verified precisely against
      `git show HEAD:convex/schema.ts` / `git show HEAD:convex/speakers.ts`, the same
      technique used for the `device_tokens` commit), commits, removes the worktree, and
      confirms `main`'s working tree checksums are unchanged before/after via `md5`.
      Never push. Record the exact branch name + commit hash in the final report.

## iOS (namos-sessions-ios) — do not start until B1–B3 verified

**Confirmed real signatures (do not let Codex invent different ones):**
- `speakers:list` — query, args `{ eventId }`, returns `Speaker[]` (organizer-only via
  `assertEventOrganizerAccess`). Fields: `_id`, `eventId`, `email`, `firstName`,
  `lastName`, `bio?`, ...profile fields..., `headshotStorageKey?`,
  `confirmationStatus?`, `status`, `createdAt`, `updatedAt`, plus (after B1)
  `checkedInAt?`, `checkedInByUserId?`.
- `speakers:checkIn` / `speakers:undoCheckIn` — mutations, args
  `{ eventId, speakerId }` (confirm exact arg shape against what Codex actually wrote
  in B2 before building the iOS call — don't assume before backend lands).
- Headshot URL: `speakers:headshotUrl` is scoped to the *owning* speaker portal
  identity (`scopedOwnedSpeaker`), NOT usable from the organizer-side check-in list —
  v1 check-in rows show initials/placeholder instead of a fetched headshot image; do
  not attempt to call `headshotUrl` per-row from the organizer app.

- [x] **1. Speaker model update.** Add `checkedInAt: Double?` and
      `checkedInByUserId: String?` to whatever `Speaker` decodable model exists (check
      `ConvexModels.swift` — if no `Speaker` struct exists yet, add one matching the
      real `speakers` table fields, decoding only what the check-in screen needs, not
      every profile field).

- [x] **2. Check-in ViewModel + View.** New
      `NamosSessions/Features/CheckIn/CheckInViewModel.swift` and `CheckInView.swift`,
      same shape as `TasksViewModel` (`refresh()`, `startSubscription()` via
      `ConvexLiveClient` subscribing to `speakers:list`, `@Published var speakers`,
      `isLoading`, `errorMessage`). Not-yet-arrived speakers sort to the top. Client-side
      text search by name (no server query). Segmented control: "All" / "Not checked
      in." Row: name, initials placeholder (no headshot fetch), checked-in toggle.

- [x] **3. Tap-to-toggle.** Tapping a row's toggle calls `checkIn`/`undoCheckIn`
      immediately — optimistic update in the local list (same pattern as
      `TasksViewModel.toggleComplete`), roll back via `refresh()` on failure. No
      confirmation dialog (per requirements.md — undo is one tap away).

- [x] **4. Wire the tab.** Add "Check-in" tab to `ContentView.swift`'s `TabView`
      (checkmark/person icon, e.g. `person.crop.circle.badge.checkmark`), alongside the
      existing tabs. Empty state: "No speakers for this event yet."

## After each iOS task

1. `xcodegen generate` (only if `project.yml` changed).
2. `xcodebuild build -project NamosSessions.xcodeproj -scheme NamosSessions -destination 'platform=iOS Simulator,id=76A049CC-DF8A-449A-9794-CACD2AECBC1F' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES` — must show BUILD SUCCEEDED.
3. Install + launch in the simulator, confirm no `Fatal error` in console output.
4. Screenshot the new/changed screens, check they match NamosColor/NamosDesignSystem.
5. Check off the task in this file.

## Final report

List which tasks were completed, which were skipped and why, whether the backend
change was committed (branch name + commit hash if so), and the exact
`xcodebuild`/simulator commands used to verify each iOS task.
