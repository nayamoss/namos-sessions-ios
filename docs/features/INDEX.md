# Feature Index — Namos Sessions iOS

Single source of truth for what exists, what's building, and what's been deliberately left alone
in the native SwiftUI companion app. **Every agent updates this file as part of the work it does.**

- Current unfinished work and the next agent's brief: [`../HANDOFF-NEXT-AGENT.md`](../HANDOFF-NEXT-AGENT.md)
- Backend (Convex functions, schema, web app): `namos-sessions-webapp`
- Sibling repositories: `namos-sessions-webapp` (private), `namos-sessions-public` (OSS mirror),
  `namos-sessions-marketing`

**Status values:** `planned` · `in-progress` · `blocked` · `done` · `cut`

**Last updated:** 2026-08-17 — first index for this repo. The app is a native SwiftUI (iOS 17+)
companion to the web app, sharing its Convex backend and Clerk auth; it has no backend of its own.
Nine feature packages exist in `docs/features/`, and every one of them is indexed below.

Two things worth knowing before reading the statuses:

1. **`**Status:** In Review` inside a plan doc is a planning-workflow marker, not implementation
   state.** Statuses here are derived from shipped Swift under `NamosSessions/Features/` and from
   the verification records at the bottom of each plan, not from those headers.
2. **A passing `xcodebuild build` is not verification on this repo.** `osascript`/System Events
   cannot drive the Simulator on this Mac ("not allowed assistive access"), so host-side tap
   automation always fails. Verification means an **XCUITest** in `NamosSessionsUITests/`, which
   drives the Simulator from the inside. Where the Simulator genuinely can't exercise something,
   the suite throws `XCTSkip` rather than asserting success. Current suite: 4 XCUITests, 3 passing,
   1 skipping for a documented hardware reason.

---

## All features

| # | Feature | Status | Notes |
|---|---|---|---|
| 1 | [complete-ios-scaffold](./complete-ios-scaffold/plan.md) | `done` | The founding package. Completed the XcodeGen-generated SwiftUI scaffold into a working app, reusing the mature Clerk auth and Convex client patterns already proven in the Sentio iOS app rather than inventing them here. Shipped as the repo's initial commit. |
| 2 | [ux-audit-and-fixes](./ux-audit-and-fixes/plan.md) | `done` | Written in response to a live walkthrough where every screen checked had a real, visible problem — nothing in it is speculative. It exposed silent data loss, not just visual issues: nothing ever called `login()` on `ConvexClientWithAuth`, so every subscription was unauthenticated and never delivered (the Dashboard's `0 / — / 0 of 0` was a query's initial value, not an empty state); `replaceError(with: [])` published an empty array over already-loaded data; and sponsor detail was unreachable because `NavigationLink(value:)` can't push onto a `[MoreDestination]`-typed stack. Fixed with `ConvexLiveClient.authenticate()`, a non-emitting `catch`, an HTTP seed in every view model, and destination-based links. |
| 3 | [agent-screen-crash-fix](./agent-screen-crash-fix/plan.md) | `done` | P0. The push-to-talk mic button force-closed the app; root cause was confirmed from a real crash report, not speculation. The fix is proven by an XCUITest rather than a build, and its plan carries a verification record that the next agent is told to read first. |
| 4 | [settings-and-tab-fix](./settings-and-tab-fix/plan.md) | `done` | Tab overflow (a visible design-system violation in the shipped app — the OS-default "More" list) plus a proper Settings screen on `NamosColor` tokens. Verified: 5-or-fewer tabs screenshot-confirmed, all five relocated tabs still reachable via `MoreDestination`. **One item is source-verified only and never actually run: sign-out with confirmation.** Treat it as unproven. |
| 5 | [elevenlabs-voice-agent](./elevenlabs-voice-agent/plan.md) | `in-progress` | Everything up to audio is proven: `voice:createSession` mints a LiveKit conversation token (a signed URL was the wrong primitive), the token is accepted, and the session establishes — confirmed against the deployed backend. **Blocked on hardware, not code:** the Simulator has no microphone, so it fails at `Audio engine returned error code: -4010`, and `VoiceAgentConnectionTests` skips on exactly that string. Needs a physical iPhone to close. Tracked upstream as webapp issue #200. |
| 6 | [cfp-dashboard-crud](./cfp-dashboard-crud/plan.md) | `done` | CFP review queue, Dashboard, and Speaker/Sponsor CRUD — planned against real Convex signatures read directly from `namos-sessions-webapp/convex/`, not invented ones. All four surfaces now exist in `NamosSessions/Features/` (`Reviews/`, `Dashboard/`, `Speakers/`, `Sponsors/`), including review scoring, sponsor contacts, and sponsor detail. |
| 7 | [checkin](./checkin/requirements.md) | `done` | Day-of speaker check-in as its own field, deliberately not an overload of `speakers.confirmationStatus` — that's a pre-event RSVP with a different lifecycle, and a speaker can be `confirmed` for weeks without arriving. The backend gap the plan flagged is closed (`speakers:checkIn` / `speakers:undoCheckIn` exist upstream) and `CheckIn/` consumes both, including undo. |
| 8 | [notifications-and-live-agenda](./notifications-and-live-agenda/requirements.md) | `done` | Notifications inbox and live agenda editing, grounded in server functions that already existed (`notifications.ts`: `list`/`unreadCount`/`markRead`/`markAllRead`; `agenda.ts`: `save`/`detectConflicts`, the same conflict logic the web app uses). Both ship as `Notifications/` and `Agenda/` with `AgendaEditView`. **Note the asymmetry: the web app's notification bell is still a dead stub (webapp #158) — iOS got this first.** |
| 9 | [cfp-voice-digest](./cfp-voice-digest/requirements.md) | `planned` | Hands-free submission review — an additive mode on top of the CFP review queue in row 6, not a replacement. Deliberately queued to start only after that base screen landed, to avoid two agents colliding on the same files. No implementation exists yet (`grep -i digest` over `NamosSessions/` returns nothing). |

---

## Open threads not covered by any feature package

These live in [`../HANDOFF-NEXT-AGENT.md`](../HANDOFF-NEXT-AGENT.md) and are recorded here so they
don't get lost between sessions:

| Thread | State |
|---|---|
| Confirm ElevenLabs voice audio on a physical device | P0 for row 5. Everything before audio is proven; only the mic path is unverified. |
| Two-Convex-deployment split | **Decided upstream, not resolved.** `calculating-loris-761` is Convex's designated "production" but holds 3 stale seed events; `pastel-mosquito-479` is labeled a personal dev deployment and holds 100% of the real live data — it's what `wrangler.jsonc`, `.env.local`, and the iOS `CONVEX_BASE_URL` all point at. Bare `npx convex deploy` silently targets the empty one. Push with `CONVEX_DEPLOYMENT="dev:pastel-mosquito-479" npx convex dev --once`. The topology decision itself needs Naya, not an agent. Full writeup: `namos-sessions-webapp/docs/deployment/production.md`. |
| Live Convex subscription delivery after the JWT-template fix | `ConvexTemplateAuthProvider` now requests Clerk's explicitly named `convex` template (the old provider asked for the default JWT, which neither the backend nor the HTTP client accepts). The XCUITest suite passes but cannot distinguish WebSocket data from the HTTP seed — one real delivery still needs confirming in Console. **Do not remove the HTTP seed**; it's the resilience path when the socket is unavailable. |
| Convex Free plan limits | The CLI warns about service interruption on every deploy. Unchecked. |
| T014 — voice-triggered subagent | Deliberately unbuilt, pending Naya's sign-off. Do not start without asking. |
