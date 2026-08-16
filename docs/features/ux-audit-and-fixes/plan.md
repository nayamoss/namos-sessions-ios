# Plan

Work top to bottom. Rebuild + install+launch and actually look at (screenshot) each
screen after the item that touches it — a passing build is not verification.

- [ ] **1. Dashboard — event context + real empty states.**
      Add the current event's name as a persistent header/subtitle. Replace raw
      `0`/`—`/`0 of 0` tiles with real empty-state copy that distinguishes "genuinely
      zero" from "no data at all" (e.g. Check-in reads "No speakers yet" when the event
      has zero speakers). Check-in tile specifically should read "Not available yet"
      (not a fake `0 of 0`) since its backend isn't merged yet. Confirm each tile is
      tappable and navigates to its related tab — verify by actually observing the
      navigation in Simulator, not just reading the `onTapGesture`/`NavigationLink`
      code.

- [ ] **2. Agent screen — real chat composition, one primary voice action.**
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

- [ ] **3. New Task sheet — kill blue buttons, kill dead space, clarify fields.**
      - Add explicit `.tint(NamosColor.accent)` to the New Task sheet's toolbar.
        Also grep every other sheet/toolbar in the app for the same missing tint and
        fix those too, not just this one screen.
      - Constrain the sheet to its content height via `.presentationDetents([.medium])`
        (or similar) instead of full-screen with a dead void below the form.
      - Clarify the "FOR / Target" field: determine from `onboarding_tasks.targetType`
        whether this is meant to pick target *type* (contact/group/submission/sponsor)
        vs. a specific contact — give it an unambiguous label distinguishing "what kind
        of task" from "who/what it's for."

- [ ] **4. Task Templates — new iOS surface for existing backend.**
      No backend changes — `taskTemplates:list`, `applyToSubmission`,
      `applyToSponsor` already exist and take exactly the args read from
      `convex/taskTemplates.ts`. Add a template picker in the New Task flow (or from
      Speaker/Sponsor detail) that lists templates via `taskTemplates:list` and applies
      one via `applyToSubmission`/`applyToSponsor`. Single-template apply only — no
      bulk/multi-select UI needed.

- [ ] **5. Tasks by person — surface `speakerId`/`sponsorId` linkage.**
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
