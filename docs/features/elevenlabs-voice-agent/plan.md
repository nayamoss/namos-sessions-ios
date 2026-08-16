# ElevenLabs Conversational Voice Agent — Implementation Plan

**Do not start until:** the currently in-flight subagent build (CFP review queue,
Dashboard, Speaker/Sponsor CRUD — docs/features/cfp-dashboard-crud/) is verified
complete and reported. This feature touches the same shared files
(`ContentView.swift`, and now also `AgentChatView.swift`) that caused two real
collision bugs in the prior parallel run. Sequence, don't parallelize with that work.

## Phase 1: SDK integration

- [x] T001: Add `elevenlabs/elevenlabs-swift-sdk` to `project.yml`'s `packages`, add as
      a dependency of the `NamosSessions` target (same pattern as ClerkKit/ConvexMobile).
- [x] T002: `xcodegen generate` + resolve packages, confirm it builds with zero other
      changes first — isolate SDK-integration risk before writing any feature code.
- [x] T003: Add `NSMicrophoneUsageDescription` if not already sufficient (this app
      already has one for the existing push-to-talk feature — confirm the existing
      string covers this use case or update it) and any `UIBackgroundModes` entry
      needed for background audio (see design.md's edge-case note — confirm what the
      SDK actually requires before adding, don't guess).

## Phase 2: Session plumbing

- [x] T004: Read `convex/voice.ts` and `convex/voiceStatus.ts` directly (don't trust
      this doc's paraphrase) to confirm `createSession`/`status` args and return shapes
      haven't changed since this was written.
- [x] T005: Wire `voiceStatus:status` + `voice:createSession` calls through the existing
      `ConvexClient`, matching how every other feature in this app calls Convex.
- [x] T006: Confirm the actual ElevenLabs Swift SDK API for starting a session from a
      signed URL by reading the resolved package source directly (Package.resolved
      will have it on disk after T002) — this doc flagged uncertainty about whether
      `ElevenLabs.startConversation` takes a signed URL directly or only a
      `tokenProvider` closure; resolve this from the real SDK, not by guessing.

## Phase 3: Frontend UI (REQUIRED — never skip)

> A feature is NOT done until it is visible and usable in the UI.

### UI Spec

**VoiceConversationView** (new)
- Location: sheet/full-screen cover presented from `AgentChatView`, triggered by a new
  entry-point button/toggle placed near the existing push-to-talk mic control.
- Elements:
  - Status indicator: pulsing dot or waveform icon, centered, large.
  - Status label below it: "Connecting…" / "Listening" / "[Agent] is speaking" /
    "Connection issue" / "Voice chat is not configured for this deployment" (+ reason).
  - Mute/unmute button: large, bottom of screen, thumb-reachable, icon + label.
  - End-session button: large, visually distinct from mute (different color/position —
    an accidental tap here shouldn't be as easy as an accidental mute tap).
  - Collapsible transcript section: collapsed by default, expandable, shows turn list
    (role label + text) when expanded — reuses `NamosColor` design tokens, no borders/
    shadows, matches every other screen in this app.
  - Error state: inline red-ish (`NamosColor.warning`) text + retry button.
  - Unavailable state: reason text only, no connect affordance shown at all.
- Behavior:
  - Tap entry point → sheet opens → auto-starts connection (matches
    `VoiceSessionPanel.tsx`'s auto-start-on-mount behavior).
  - Tap mute → toggles SDK mute state, button icon/label updates.
  - Tap end → ends SDK session, dismisses sheet.
  - Tool call arrives (`pendingToolCalls`) → dispatch to the matching handler (Phase 4),
    send result back via the SDK's tool-result API.
- Data: `voiceStatus:status` (query), `voice:createSession` (action), then the
  ElevenLabs SDK's own WebSocket (not Convex) for the live conversation itself.

### Tasks

- [x] T007: Build `VoiceConversationView` with every element listed in the UI Spec above.
- [x] T008: Wire the status/session-creation flow (T005) into the view's lifecycle —
      handle loading, unavailable, and error states distinctly, not as one generic
      error blob.
- [x] T009: Add the entry point button to `AgentChatView.swift` alongside the existing
      mic control, without altering the existing push-to-talk flow.
- [x] T010: Verify the full flow in Simulator: tap entry point, see "Connecting…",
      confirm no crash. Full audio round-trip verification in Simulator is unreliable
      for microphone-dependent features — say so plainly in the verification report
      rather than claiming a full voice-conversation test happened, same honesty
      standard as every prior feature's report in this app's history.

## Phase 4: Client tools

- [x] T011: Implement `navigate_to_screen` (local, switches the app's tab/presented
      screen — no network call).
- [x] T012: Implement `get_pending_tasks_count` and `get_submission_review_status`
      (read-only, call existing `ConvexClient` queries, return a count/summary the tool
      framework hands back to the agent to speak).
- [x] T013: Implement `create_task` (mutating, calls existing `tasks:create`).
- [ ] T014: **Stop before implementing `accept_or_decline_submission`.** This is
      flagged in design.md as needing an explicit yes/no from Naya (voice-triggered CFP
      decisions while potentially driving is a product judgment call, not a technical
      one) — do not build this tool until that's answered. Report this as a
      deliberately incomplete task, not an oversight.

## Task Dependencies

Phase 1 → Phase 2 → Phase 3 (needs working session plumbing to test against) → Phase 4
(needs a working view to trigger tool calls from). T014 blocks on human input, not on
any other task — everything else in Phase 4 can ship without it.

## Verification Checklist

- [ ] All acceptance criteria in requirements.md met (except anything gated by T014).
- [ ] Feature is reachable and usable from the Agent tab, not just implemented.
- [ ] Existing push-to-talk flow in `AgentChatView` still works unchanged.
- [ ] `ContentView.swift` inspected for a clean state after this work lands — no
      duplicate declarations, no dropped tabs, same collision check every prior
      feature's verification pass has done.
- [ ] `xcodegen generate` + `xcodebuild build` succeeds.
- [ ] App installs and launches clean in Simulator (no `Fatal error`).
- [ ] Honest reporting on what could vs. couldn't be verified without a real device —
      microphone/audio-session behavior is the clearest example of something Simulator
      verification can't fully confirm.
