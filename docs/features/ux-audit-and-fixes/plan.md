# Plan

Work top to bottom. Rebuild + install+launch and actually look at (screenshot) each
screen after the item that touches it — a passing build is not verification.

- [x] **1. Dashboard — event context + real empty states.**
      Add the current event's name as a persistent header/subtitle. Replace raw
      `0`/`—`/`0 of 0` tiles with real empty-state copy that distinguishes "genuinely
      zero" from "no data at all" (e.g. Check-in reads "No speakers yet" when the event
      has zero speakers). Check-in tile specifically should read "Not available yet"
      (not a fake `0 of 0`) since its backend isn't merged yet. Confirm each tile is
      tappable and navigates to its related tab — verify by actually observing the
      navigation in Simulator, not just reading the `onTapGesture`/`NavigationLink`
      code.

- [x] **2. Agent screen — real chat composition, one primary voice action.**
      This needs actual design judgment, not a literal re-read of the old spec. Fix:
      - A message list area fills the space between header and input bar (even when
        empty — the centered icon+caption lives inside that message area, not floating
        alone in dead space above/below it).
      - One clear primary voice action: keep the push-to-talk mic as the primary
        button; the ElevenLabs conversational entry point becomes a clearly labeled
        secondary control (e.g. a labeled pill/button reading "Start voice chat"), not
        a second unlabeled icon indistinguishable from the mic. Remove/merge the third
        redundant waveform affordance — there should not be three undifferentiated
        voice icons on screen.
      - Text-input toggle stays but is visually secondary to voice, not equal-weight.
      - Use existing `NamosColor`/card/surface tokens — this is a layout/composition
        fix, not a new token fix.

- [x] **3. New Task sheet — kill blue buttons, kill dead space, clarify fields.**
      - Add explicit `.tint(NamosColor.accent)` to the New Task sheet's toolbar.
        Also grep every other sheet/toolbar in the app for the same missing tint and
        fix those too, not just this one screen.
      - Constrain the sheet to its content height via `.presentationDetents([.medium])`
        (or similar) instead of full-screen with a dead void below the form.
      - Clarify the "FOR / Target" field: determine from `onboarding_tasks.targetType`
        whether this is meant to pick target *type* (contact/group/submission/sponsor)
        vs. a specific contact — give it an unambiguous label distinguishing "what kind
        of task" from "who/what it's for."

- [x] **4. Task Templates — new iOS surface for existing backend.**
      No backend changes — `taskTemplates:list`, `applyToSubmission`,
      `applyToSponsor` already exist and take exactly the args read from
      `convex/taskTemplates.ts`. Add a template picker in the New Task flow (or from
      Speaker/Sponsor detail) that lists templates via `taskTemplates:list` and applies
      one via `applyToSubmission`/`applyToSponsor`. Single-template apply only — no
      bulk/multi-select UI needed.

- [x] **5. Tasks by person — surface `speakerId`/`sponsorId` linkage.**
      No backend changes — `onboarding_tasks` already has `speakerId`/`sponsorId` and
      `by_speaker`/`by_sponsor` indexes; `tasks:list` already accepts `speakerId`. At
      minimum, show a person's linked tasks on their Speaker/Sponsor detail screen.
      Ideally also add a filter/group-by-person option on the main Tasks list.

## After each task

1. `xcodegen generate` (if `project.yml` changed).
2. `xcodebuild build -project NamosSessions.xcodeproj -scheme NamosSessions -destination 'platform=iOS Simulator,id=76A049CC-DF8A-449A-9794-CACD2AECBC1F' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES` — must succeed.
3. Install + launch in Simulator, screenshot the affected screen(s) via
   `xcrun simctl io booted screenshot`, and confirm visually against the fix
   description above before checking the box.

## Final report

For each of the 5 issues: state what changed, and attach/describe the actual
screenshot evidence used to confirm it, not just "matches the spec."


## Verification record (2026-08-16)

All five boxes above are checked on the strength of an actual walkthrough, not a build.
`NamosSessionsUITests/UXAuditScreenshotTests` drives each screen in the Simulator and
attaches a screenshot; host-side tap automation is unavailable on this machine
(`osascript is not allowed assistive access`), which is why verification kept falling
through before. Run it with:

    xcodebuild test -project NamosSessions.xcodeproj -scheme NamosSessions \
      -destination 'platform=iOS Simulator,id=76A049CC-DF8A-449A-9794-CACD2AECBC1F' \
      -only-testing:NamosSessionsUITests

Observed on iPhone 16 Pro / iOS 26.5, all three tests passing:

1. **Dashboard** — event name renders as a wrapping subtitle; tiles show real values
   (Tasks 15, Reviews 4, Check-in 0 of 86, Next "Verification Test Title",
   Notifications "All caught up"). The test fails outright if any tile is still
   reporting "loading".
2. **Agent** — one primary mic with a "Hold to talk" caption, one labelled
   "Start voice chat" secondary, muted keyboard toggle. The third lookalike waveform
   glyph is gone; the empty state sits inside the message area.
3. **New Task** — medium detent instead of a full-height void; Cancel/Create render in
   `NamosColor.accent` rather than system blue; the target picker is labelled
   "What is this task about?" / "Kind of task".
4. **Task templates** — reachable from a sponsor's Tasks screen; the picker listed six
   real templates from `taskTemplates:list` (Standard Speaker Onboarding, Keynote
   Speaker, Workshop Facilitator, Panelist, Virtual/Remote Speaker, …).
5. **Tasks by person** — a sponsor's own tasks render grouped Outstanding/Done
   (Convex: "Logo received", "Booth confirmed" outstanding; "Contract signed" done);
   speakers use the server-side `speakerId` filter.

### Bugs found while verifying, and fixed here

These were not in the audit doc — they surfaced only because the screens were actually
driven rather than reasoned about.

- **No live data anywhere.** Nothing ever called `login()` on `ConvexClientWithAuth`, so
  every subscription in the app was unauthenticated and silently never delivered. The
  Dashboard's `0 / — / 0 of 0` was not a missing empty state, it was the initial value
  of a query that never returned. Fixed by `ConvexLiveClient.authenticate()`, plus an
  HTTP seed in every view model so a bad socket can no longer blank a screen.
- **`replaceError(with: [])` erased good data.** A failing subscription published an
  empty array over whatever had already loaded. Replaced with a non-emitting `catch`.
- **Sponsor detail was unreachable.** `NavigationLink(value: sponsor)` cannot push onto
  MoreView's `NavigationStack` because that stack's path is typed `[MoreDestination]`.
  Tapping a sponsor did nothing at all. Switched to a destination-based link.
