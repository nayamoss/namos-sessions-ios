# Plan

Work top to bottom; each is independently shippable. Rebuild + relaunch-in-Simulator
after every item that touches app startup, Info.plist, or auth.

- [x] **1. Real sign-in UI.** Port `sentio-ios-app-v2/SignInModal.swift` into
      `NamosSessions/Auth/`. It already drives ClerkKit's presentation-based sign-in
      flow against `Clerk.shared` — adapt branding/copy only, keep the flow logic.
      Wire it into `ContentView.swift`'s `SignInPlaceholderView` (replace it entirely).
      Verify: with a real Clerk publishable key in `Config.local.xcconfig`, the app
      shows real sign-in UI instead of the "Configuration needed" placeholder, and a
      successful sign-in transitions to the event picker.

- [x] **2. Live Convex subscriptions.** Currently `ConvexClient.swift` polls over HTTP.
      Add the official `convex-swift` (get-convex) SPM package and give `AgentChatViewModel`,
      `TasksViewModel`, and `AgendaViewModel` a live-subscription path alongside (or
      replacing) the HTTP one — same function names/args, just pushed instead of polled.
      Keep the HTTP path as a fallback/simpler option if convex-swift's API doesn't map
      cleanly to one of the three screens; note in code why if so.

- [x] **3. Task creation + agenda "happening now" polish.** `TasksView` is read+toggle
      only — add a create-task sheet calling `tasks:create` (see `convex/tasks.ts`).
      `AgendaViewModel.happeningNow` exists but isn't surfaced anywhere prominent — add
      a "Now" section/banner at the top of `AgendaView` when it's non-nil.

- [x] **4. Agent run proposals (approve/reject).** `convex/agentRuns.ts` has
      `approveTaskProposal` for `agent_action_proposals` — when a run's status is
      `needs_approval`, `AgentChatView` currently has no UI for it. Add an approval card
      inline in the chat (show the proposed tasks, Approve/Reject buttons) using
      `AgentRunDetail.proposals` (extend `AgentRunDetail`/add a `proposals: [Proposal]`
      decode — check `convex/schema.ts`'s `agent_action_proposals` table for the shape).

- [x] **5. Push notifications wiring.** `convex/notifications.ts` already has the data
      model. Add APNs registration (`UNUserNotificationCenter`, `AppDelegate` token
      handling) and a Convex mutation call to register the device token against the
      signed-in user — check whether `namos-sessions-webapp/convex/` already has (or
      needs) a `deviceTokens` table/mutation; if not, this task is backend + iOS, flag
      that split clearly in your final report rather than inventing backend schema
      unilaterally.

- [x] **6. App icon + bundle identity for TestFlight.** Replace the empty
      `AppIcon.appiconset`/`AccentColor.colorset` placeholders with real assets (ask if
      brand assets aren't available in the repo — don't invent a logo). Confirm
      `PRODUCT_BUNDLE_IDENTIFIER` / `DEVELOPMENT_TEAM` are ready for a real Apple
      Developer account (leave `DEVELOPMENT_TEAM` empty in `project.yml` if you don't
      have one — that's a human step, not yours to fill in).

## After each task

1. `xcodegen generate` (only if `project.yml` changed).
2. `xcodebuild build -project NamosSessions.xcodeproj -scheme NamosSessions -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` — must succeed.
3. For anything touching startup/auth: install + launch in Simulator, confirm no
   `Fatal error` in `xcrun simctl launch --console` output.
4. Check the corresponding box in this file.

## Final report

List which tasks were completed, which were skipped and why, and the exact
`xcodebuild`/simulator commands you used to verify each one — don't just say "it builds."
