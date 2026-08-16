# ElevenLabs Conversational Voice Agent — Technical Design

## Database / Schema Changes

N/A — no new Convex tables or fields. `voice:createSession` and `voiceStatus:status`
already exist and are backend-agnostic (not React-specific); iOS calls them exactly as
the webapp does, over the same `ConvexClient`/`ConvexLiveClient` already integrated.

---

## Backend / API

### Affected Existing Endpoints (Convex functions, called as-is — zero changes)

| Kind | Path | Used for |
|------|------|----------|
| query | `voiceStatus:status` | Check `{ available: true }` / `{ available: false, reason }` before showing the voice UI, exact same gate the webapp uses. |
| action | `voice:createSession` | Returns `{ signedUrl, agentId }` (or `{ unavailable: true, reason }`) — organizer-gated via `assertEventOrganizerAccess`/`assertEventOrganizerAction`, already enforced server-side. |

### New Endpoints

None required for connecting. **Possible new endpoints only if a specific mutating
client tool needs one that doesn't already exist** — every tool in the table below maps
to an existing mutation/query already used elsewhere in this app (Tasks, Agenda,
Submissions, Notifications), so no new Convex functions are anticipated for v1's tool
set. If Codex finds a tool genuinely needs new backend logic, that's a stop-and-flag
moment, not something to invent inline (same rule as every other backend addition in
this app's history).

### Validation & Business Logic

None new — every mutating client tool call goes through the same
`assertEventOrganizerAccess`-gated Convex mutation any other screen would call. The
voice agent is not a privileged caller; client tools are literally still calling the
plain `ConvexClient.shared.mutation(...)` this app already has, just triggered by a
tool-call event instead of a button tap.

---

## Frontend Components (SwiftUI, not React — adapting the template's headers)

### Modified Components

| File Path | Change |
|-----------|--------|
| `NamosSessions/App/ContentView.swift` | Add an entry point into voice conversation mode from the Agent tab (e.g. a toolbar button/toggle alongside the existing push-to-talk mic) — do not remove or restructure the existing tab. |
| `NamosSessions/Features/AgentChat/AgentChatView.swift` | Add the entry point button described above; the existing push-to-talk flow is untouched. |

### New Components

**VoiceConversationView**
- File: `NamosSessions/Features/VoiceAgent/VoiceConversationView.swift`
- Props: `eventId: ConvexId`
- Location: presented as a sheet/full-screen cover from `AgentChatView`'s new entry
  point (per NFR-002, minimal chrome — this should read as almost nothing to look at,
  not a busy screen).
- Elements:
  - Large centered status indicator (pulsing dot or waveform), text label showing one
    of: "Connecting…", "Listening", "[Agent name] is speaking", "Connection issue".
  - Mute/unmute button (large, thumb-reachable, bottom of screen).
  - End-session button (large, clearly distinct from mute — accidental taps here end
    the whole conversation).
  - Optional collapsible transcript list below the status indicator (per FR-005) —
    collapsed by default while driving-safety is the point; organizer can expand it
    if they're not driving. Same turn-list concept as `VoiceSessionPanel.tsx`
    (role label + content per turn), not a literal port (SwiftUI list, not React).
  - Unavailable state: if `voiceStatus:status` returns `available: false`, show the
    `reason` string directly (same message the webapp shows) instead of any connect UI.
  - Error state: inline text + retry button, mirrors `VoiceSessionPanel.tsx`'s error
    handling.
- Behavior:
  - On appear: query `voiceStatus:status`; if unavailable, show that state and stop.
  - If available: call `voice:createSession`, then start the ElevenLabs `Conversation`
    with the returned signed URL/agent ID (exact SDK call — `ElevenLabs.startConversation`
    takes a `tokenProvider` closure per the SDK's documented pattern; confirm during
    implementation whether a signed-URL-specific entry point exists in the actual
    installed package version, don't assume the exact overload without reading the
    real SDK source Codex will have on disk).
  - Register client tools (see table below) before/at session start.
  - Mute button toggles the SDK's mute state (`$isMuted`).
  - End button calls the SDK's end-session method, dismisses the view.
- Third-party: `elevenlabs/elevenlabs-swift-sdk` (SPM, latest — confirm exact version
  against what's current when this is built, the search that grounded this doc found
  3.2.2 but pin whatever `Package.resolved` actually resolves). iOS 13+ min, no
  conflict with this app's iOS 17 deployment target.

### Client Tools — the actual "voice controls the app" mechanism

| Tool name | Type | Maps to | Notes |
|-----------|------|---------|-------|
| `navigate_to_screen` | Navigation (local, no network) | Switches the app's selected tab / presents a screen | Screens: Agent, Tasks, Agenda, Check-in, Notifications, Dashboard, CFP review queue (whichever of these exist by the time this is built — check `ContentView.swift`'s current tab set, don't assume the tab list from an older doc). |
| `get_pending_tasks_count` | Read-only query | `tasks:list`, count client-side | Spoken back by the agent, e.g. "you have 4 pending tasks." |
| `get_submission_review_status` | Read-only query | `submissions:list` / `evaluations:myQueue`, count | Same pattern. |
| `create_task` | Mutating | `tasks:create` | Judgment call flagged here: a voice-created task is low-risk (easily undone/edited later) — reasonable for v1. |
| `accept_or_decline_submission` | Mutating, higher stakes | `submissions:decide` | Flagging explicitly: deciding a CFP submission by voice alone, while driving, is a real judgment call about whether that's a good idea at all — consider requiring the agent to ask for explicit spoken confirmation ("did you mean accept Jane's talk on X?") before calling this tool, or leaving it out of v1 and only wiring the two read-only + navigate + create_task tools first. This is not a decision to make silently either way — flag it for Naya rather than assuming yes or no. |

---

## State / Data Flow

Signed URL fetch (`voice:createSession`, one-shot action call) → ElevenLabs SDK opens
its own WebSocket directly to ElevenLabs' servers (not proxied through Convex) →
`Conversation`'s `@Published` properties (`messages`, `agentState`, `state`, `isMuted`,
`pendingToolCalls`) drive `VoiceConversationView` reactively → a pending tool call is
matched against the local tool-name switch, executed (either a local navigation action
or a `ConvexClient`/`ConvexLiveClient` call reusing existing query/mutation
infrastructure), and the result is sent back via the SDK's tool-result API so the agent
can speak a response incorporating it.

---

## Auth / Permissions

- Session creation: organizer-only, enforced server-side by `voice:createSession`
  (unchanged, already correct).
- Every mutating client tool: goes through the same Convex mutation with the same
  `assertEventOrganizerAccess` guard every other caller uses — the voice layer adds no
  new authorization path and must not be given one.
- ElevenLabs WebSocket itself: authenticated via the signed URL, which is short-lived
  and scoped by ElevenLabs — the iOS app never sees or stores `ELEVENLABS_API_KEY`.

---

## Edge Cases & Error States

- **Not configured** (`voiceStatus:status` → unavailable): show the reason text, no
  connect button — exact webapp behavior, already correct to copy.
- **Signed URL fetch fails** (network, Convex error): inline error + retry, matching
  `VoiceSessionPanel.tsx`'s pattern.
- **WebSocket drops mid-conversation**: SDK's `state` transitions to `.ended` or
  similar — show "Connection issue," offer reconnect (new `createSession` + new SDK
  session — signed URLs are single-use/short-lived, don't try to reuse one).
- **Microphone permission denied**: reuse this app's existing permission-request
  pattern from `VoiceCaptureService.swift` (same `AVAudioSession`/mic permission
  concepts), show a clear "microphone access required" state rather than a silent
  failure.
- **Backgrounded/screen off**: `AVAudioSession` category needs to support continued
  audio — confirm during implementation whether the ElevenLabs SDK manages its own
  audio session category or expects the host app to configure one (check the SDK
  source/docs directly rather than assuming); `UIBackgroundModes: audio` may need
  adding to `Info.plist`/`project.yml` alongside the existing `remote-notification`
  background mode.
- **Interruption** (phone call, another app's audio): standard `AVAudioSession`
  interruption notification handling, pause and allow resume — don't crash, don't
  silently lose the session.

---

## Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Signed-URL vs. embedding API key client-side | Signed URL via `voice:createSession` | Already the established, secure pattern from the webapp; no reason to diverge. |
| New Convex backend work | None for connecting; possibly none at all | Every planned tool maps to an existing function — reuse over invention, same principle as every other feature in this app. |
| Replace vs. extend existing `AgentChatView` | Extend | Push-to-talk stays useful when not driving/hands-free isn't needed; conversational mode is a new, additive entry point, not a rebuild. |
| Mutating client tools scope | `create_task` yes; `accept_or_decline_submission` flagged for explicit sign-off | A voice-triggered CFP accept/decline while driving is a real product-judgment question, not purely technical — see the tool table note. |

## Dependencies

**Requires:** ElevenLabs Swift SDK (SPM), the already-existing `voice:createSession`/
`voiceStatus:status` Convex functions, this app's existing `ConvexClient`/
`ConvexLiveClient` for tool-call-triggered mutations/queries.

**Enables:** the CFP Voice Digest concept (`docs/features/cfp-voice-digest/`) could
later use the same ElevenLabs session for a more conversational "review my queue" mode
instead of pure TTS playback — not required for v1, noted as a natural follow-on.

## Risks & Mitigations

- **Collision with in-flight work**: another subagent is actively building the CFP
  review queue, Dashboard, Speaker/Sponsor CRUD screens right now, touching
  `ContentView.swift` repeatedly. This feature also touches `ContentView.swift` and
  `AgentChatView.swift`. Mitigation: do not delegate this to Codex until that other
  work is verified complete and reported — same sequencing rule already applied to the
  CFP Voice Digest doc.
- **Driving-while-using-a-phone-at-all**: even hands-free, glancing at a phone screen
  to start/end a session has real safety implications. Mitigation: the entry point
  should be reachable via a single obvious tap, and once started, the design goal is
  zero further screen interaction needed for the core loop (per NFR-002) — this is a
  design constraint, not a solved problem, and should stay visible as one during build.
