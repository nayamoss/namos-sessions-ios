# Plan

Work top to bottom: backend first (task 0), then iOS. Tasks 1+2 can run in parallel
(different new files); tasks 3+4 can run in parallel with each other and with 1+2 — but
ALL FOUR touch `ContentView.swift` for tab wiring, so a manual merge-conflict inspection
pass after each wave is mandatory, not optional. Rebuild + relaunch-in-Simulator after
every task.

**Confirmed real signatures (do not let Codex invent different ones) — see
requirements.md for the full list; corrections/additions found during a direct-read
verification pass:**
- `evaluations:myQueue` — query, no args, returns `ReviewerQueueRow[]`
  (`assignmentId, eventId, submissionId, submissionTitle, submissionAnswers, speakerNames?,
  round, planName, scoringScaleMax, anonymized, criteria?, review?`). Event and criteria
  come bundled per-row — no separate `listPlans` call needed for the scoring sheet.
- `evaluations:save` — mutation, args `{ id?, assignmentId?, eventId, submissionId,
  reviewerName, score?, comments?, criteriaScores? }`.
- `evaluations:listPlans` — query, args `{ eventId }`, organizer-only (throws for a
  plain reviewer) — only needed if building the organizer-side plan view, NOT needed for
  the reviewer scoring sheet since `myQueue` already includes `criteria`/`scoringScaleMax`
  per row.
- `submissions:decide` — mutation, args `{ submissionId, status: "accepted"|"declined" }`.
- `submissions:list` — query, args `{ eventId, speakerId? }`; omit `speakerId` for the
  organizer's full-event view.
- `sponsorTiers:list` — query, args `{ eventId }`, returns tiers with `sponsorCount`.
- `sponsors:create` / `update` / `remove` / `list` / `get` — as documented in
  requirements.md, confirmed unchanged.
- `tasks:list` — query, args `{ eventId, speakerId? }`, returns ALL rows — no cheaper
  pending-count query exists. Dashboard's pending-tasks tile filters client-side.
- `notifications:unreadCount` — query, no args, caller-scoped.
- **IMPORTANT — pre-existing gap unrelated to this plan, do not fix as part of these
  tasks**: `speakers:checkIn`/`speakers:undoCheckIn` and `speakers.checkedInAt`/
  `checkedInByUserId` are called by the already-shipped `CheckInViewModel.swift` but do
  **not exist** in `convex/speakers.ts`/`schema.ts` — confirmed via direct grep. This
  means the Dashboard's "check-in progress" tile (task 2) cannot use `checkedInAt`
  server-side yet; build it reading `speakers.checkedInAt` client-side as documented in
  the model (it will just always show 0 until that gap is separately fixed) and flag
  this clearly in the final report. Do NOT silently add the missing checkIn backend as
  part of this plan — it's a different feature's regression, out of scope here.
- For the new `speakers:organizerUpdate` mutation, copy the exact shape of
  `speakers:setConfirmationStatus` (guard-first, then fetch+verify `speaker.eventId`,
  then `ctx.db.patch`) — NOT `checkIn`, since `checkIn` doesn't exist server-side.

- [x] **0. Backend: `speakers:organizerUpdate` mutation.** Add to
      `convex/speakers.ts`: `mutation({ args: { eventId: v.id("events"), speakerId:
      v.id("speakers"), firstName: v.string(), lastName: v.string(), email: v.string(),
      confirmationStatus: v.optional(v.union(v.literal("awaiting"), v.literal("confirmed"),
      v.literal("declined"))) }, handler: assertEventOrganizerAccess(ctx, args.eventId)
      first, then verify speaker.eventId === args.eventId, then ctx.db.patch(...,
      { firstName, lastName, email, confirmationStatus, updatedAt: Date.now() }) })`.
      Done directly (not via Codex) in an isolated git worktree off webapp `main`,
      verified byte-identical on main's working tree before/after, committed alone,
      never pushed.

- [x] **1. CFP / Submissions review queue.** New `Features/Reviews/` folder:
      `ReviewsViewModel.swift` + `ReviewsView.swift` (reviewer mode: list from
      `evaluations:myQueue`, tap → `ReviewScoringSheet.swift` rendering `criteria` per
      row, number criteria as stepper up to `max`, text criteria as text field, overall
      comments field, submit via `evaluations:save`) and `Features/Submissions/`:
      `SubmissionsViewModel.swift` + `SubmissionsView.swift` (organizer mode: list from
      `submissions:list`, status filter chips pending/accepted/declined, tap → detail
      view rendering `answers` generically as a key/value list, Accept/Decline buttons
      calling `submissions:decide`). Add `ReviewerQueueRow`, `Criterion`,
      `CriterionScore`, `Submission` model structs to `ConvexModels.swift`. Determine
      role by whether `evaluations:myQueue` returns any rows OR by an explicit
      organizer-check — use your judgment, note which you picked. New 6th tab
      "Reviews" (or split into two tabs if that reads cleaner — note your choice).

- [x] **2. Dashboard / home screen.** New `Features/Dashboard/`: `DashboardViewModel.swift`
      + `DashboardView.swift`. Stats-only grid of tappable tiles: unread notifications
      count (`notifications:unreadCount`), pending tasks count (`tasks:list` filtered
      client-side for not-completed), now/next agenda item (reuse
      `AgendaViewModel.happeningNow` pattern), review queue size
      (`evaluations:myQueue.count`, only shown if > 0 or user has any assignments),
      check-in progress (`speakers:list` count of `checkedInAt != nil` — will read 0 per
      the gap noted above, that's expected and documented, not a bug in this task).
      NO greeting, NO date text, NO narrative copy — spare stat tiles only, matching
      NamosColor tokens (off-white surface, no borders/shadows). Make Dashboard the
      FIRST tab in `ContentView.swift`'s `TabView` (before Agent), each tile navigates
      to its corresponding tab.

- [x] **3. Speaker CRUD.** New `Features/Speakers/`: `SpeakersViewModel.swift` +
      `SpeakersView.swift` + `SpeakerEditSheet.swift`. List view (reachable from a new
      "Speakers" entry point — either its own tab or accessible from Check-in tab, your
      judgment, note which) with a "+" toolbar button opening `SpeakerEditSheet` (first
      name, last name, email, confirmation status picker) calling `speakers:create`.
      Tapping an existing speaker opens the same sheet pre-filled, calling the new
      `speakers:organizerUpdate` from task 0. Optimistic update + rollback pattern
      matching `TasksViewModel`. Add `private struct EmptyResult: Decodable {}`
      locally in this file's own scope — do NOT reuse or share one from another file.

- [x] **4. Sponsor CRUD.** New `Features/Sponsors/`: `SponsorsViewModel.swift` +
      `SponsorsView.swift` + `SponsorEditSheet.swift` + `SponsorDetailView.swift` +
      `SponsorContactEditSheet.swift`. List + create/edit sheet (name, tier picker
      populated from `sponsorTiers:list`, tier optional so don't block save, status
      picker, website, notes) calling `sponsors:create`/`sponsors:update`. `remove` is
      destructive — require a native iOS confirmation alert before calling it, never a
      bare tap. Tapping into a sponsor opens `SponsorDetailView` (from `sponsors:get`)
      showing its contacts with a lightweight add-contact sheet
      (`SponsorContactEditSheet`) — check the real backend for the contact
      create/update mutation name in `sponsors.ts`/`sponsorContacts` before assuming one
      exists; if contacts are only ever returned nested in `sponsors:get` with no
      standalone create mutation, read the file again for the actual mutation name
      before inventing one. Add `Sponsor`, `SponsorTier`, `SponsorContact` model structs
      to `ConvexModels.swift`. New "Sponsors" tab.

## Tab wiring caution (all 4 tasks touch this)

`ContentView.swift` currently has 5 tabs: Agent, Tasks, Agenda, Check-in, Notifications.
After this plan it should have up to 9 (Dashboard first, then Reviews/Submissions,
Speakers, Sponsors, plus the original 5) — if that's too many for a `TabView`, consider
folding Speakers into the Check-in tab's navigation stack and Reviews/Submissions into
one tab, and say so in the final report rather than silently dropping a feature. After
any two tasks land, manually re-read `ContentView.swift` for a clean merge before
building the next wave — do not trust self-reports that "the tab was added cleanly."

## After each task

1. `xcodegen generate` (only if `project.yml` changed — new Swift files under the
   existing source dir do not require this, but run it anyway if unsure).
2. `xcodebuild build -project NamosSessions.xcodeproj -scheme NamosSessions -destination 'platform=iOS Simulator,id=76A049CC-DF8A-449A-9794-CACD2AECBC1F' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES` — must show BUILD SUCCEEDED.
3. Install + launch in the simulator, confirm no `Fatal error` in console output.
4. Screenshot the new/changed screens, check they match NamosColor/NamosDesignSystem
   (no borders, no shadows, off-white surfaces).
5. Check off the task in this file.

## Final report

For each of the 4 iOS tasks plus the backend task: what was built, exact verification
commands + real output, build/launch status, screenshot description, anything
skipped/blocked with a clear reason (including the pre-existing checkIn backend gap).
State the new mutation's branch name and commit hash.
