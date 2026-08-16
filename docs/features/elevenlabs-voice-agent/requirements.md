# ElevenLabs Conversational Voice Agent — Requirements

**Type:** Feature
**Status:** In Review
**Priority:** High
**Last Updated:** 2026-08-16

## Problem Statement

Organizers running an event solo (the motivating case: an overwhelmed organizer during
a hackathon last week, unable to keep up with reviewing/responding to people because
every operation required sitting down at a screen and keyboard) need to operate the
event hands-free — while driving, walking between venues, or otherwise away from a
desk. The app already has a voice-*input* agent (`AgentChatView.swift`, push-to-talk →
transcribe → send as text to `agentRuns.ts`), but that's still a "look at the screen,
read the response" loop. It is not safe or usable while driving, and it's a single-shot
exchange, not a real back-and-forth conversation.

The webapp already solved real-time two-way voice conversation for desktop
(`VoiceSessionPanel.tsx`, ElevenLabs Conversational AI via `@elevenlabs/react`, backed
by `convex/voice.ts`'s `createSession` action). None of that is iOS-specific — the
Convex action is plain, reusable server logic. This is native iOS's turn to use it.

## User Stories

**As an** organizer driving to a venue, **I want to** talk to the agent hands-free and
have it act on what I say (create a task, check submission counts, navigate me to a
screen) **so that** I can keep operations moving without needing to stop and use my
phone visually.

**Acceptance Criteria:**
- GIVEN the organizer opens voice chat and grants microphone permission, WHEN they
  speak, THEN the agent responds with real-time speech (not a transcript they have to
  read).
- GIVEN a voice session is active, WHEN the organizer asks the agent to go to a specific
  screen ("take me to the CFP review queue"), THEN the app navigates there while the
  voice session keeps running.
- GIVEN ElevenLabs isn't configured for this deployment (`voice:status` returns
  `available: false`), WHEN the organizer opens voice chat, THEN they see the same
  "not configured" message the webapp already shows, not a crash or silent failure.
- GIVEN the organizer is driving (screen off or backgrounded), WHEN they're mid
  conversation, THEN audio continues and the session doesn't silently die (subject to
  iOS background-audio constraints — see design.md's audio-session section).

## Functional Requirements

- FR-001: Add ElevenLabs Swift SDK (`elevenlabs/elevenlabs-swift-sdk`, SPM) to the iOS
  project.
- FR-002: New voice conversation screen/mode reachable from the existing Agent tab —
  extends it, does not replace the existing push-to-talk single-shot flow (that stays
  useful for quiet environments / precise text-like requests; conversational mode is
  for hands-free/driving).
- FR-003: Session bootstrap reuses `voice:createSession` and `voiceStatus:status`
  exactly as the webapp does — no new Convex backend function needed for connecting.
- FR-004: Register ElevenLabs "client tools" so the agent can trigger real actions:
  at minimum, in-app navigation ("go to Tasks/Agenda/CFP/Check-in/Notifications/
  Dashboard") and read-only status queries the agent can speak back (e.g. "how many
  submissions are pending"). Mutating actions (create a task, accept a submission) are
  a judgment call per action — see design.md's tool list and its safety notes.
- FR-005: Live transcript UI (mirrors `VoiceSessionPanel.tsx`'s turn list) for when the
  organizer *is* looking at the screen, but the core interaction must not require it.
- FR-006: Background audio session so the conversation continues with the screen off/
  app backgrounded, within what iOS actually permits for this audio category.

## Non-Functional Requirements

- NFR-001: No ElevenLabs API key ever touches the iOS client — same server-brokered
  signed-URL pattern the webapp already uses is mandatory, not optional.
- NFR-002: Driving-safety-conscious UI: minimal visual chrome while a session is
  active, large/glanceable status only, no UI element that requires reading fine print
  to operate. Full CarPlay integration is explicitly out of scope for this pass (needs
  a separate Apple entitlement and CarPlay-template UI) but this UI should not preclude
  it later.
- NFR-003: Mutating client tools must run through the exact same authorized Convex
  mutations every other screen uses (`assertEventOrganizerAccess`, etc.) — the voice
  agent gets no special/elevated access path.

## Out of Scope

- Full CarPlay app extension/template UI (future work, flagged not forgotten).
- Replacing the existing push-to-talk `AgentChatView` — this is additive.
- Telephony/phone-call-based agent access (ElevenLabs supports this; not needed here).
- Multi-language voice support beyond whatever the configured ElevenLabs agent already
  handles server-side.
- Building new mutating client tools beyond what's listed in design.md's tool table —
  expanding the tool set is a fast follow-up, not part of this initial pass.

## Success Metrics

- An organizer can complete a full voice session (connect → speak → get a spoken
  response → disconnect) without looking at the screen after the initial tap to start.
- At least one navigation client tool and one read-only status client tool work
  end-to-end, verified in the Simulator (voice session itself can't be fully verified
  in Simulator — see design.md's verification notes) and ideally on a real device.
