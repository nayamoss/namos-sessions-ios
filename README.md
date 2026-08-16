# Namos Sessions — iOS (scaffold)

Voice-first companion to the namos-sessions-webapp. No new backend — every screen calls
the **same Convex functions** the webapp calls, authenticated with the **same Clerk
"convex" JWT template**. Ported the generic pieces (Clerk auth bootstrap, Keychain,
haptics) from the Sentio iOS app's proven patterns rather than starting from zero.

## What's real right now

- Builds and launches (verified: `xcodebuild build` + boots in iOS Simulator).
- Sign-in bootstrap wired to ClerkKit (crashes only on the placeholder key in
  `Config.xcconfig.example` — drop in a real `pk_test_…`/`pk_live_…` key and it's live).
- `ConvexClient.swift` — calls Convex's documented HTTP API (`/api/query`, `/api/mutation`,
  `/api/action`) with a Clerk-issued bearer token. Hits the exact same
  `assertEventOrganizerAccess` checks as the webapp.
- Three feature screens, each backed by an existing Convex function:
  - **Agent** (`AgentChatView`) — push-to-talk mic → `agentRuns:create` /
    `agentRuns:respond`, polls `agentRuns:get`.
  - **Tasks** (`TasksView`) — `tasks:list` / `tasks:setStatus`.
  - **Agenda** (`AgendaView`, read-only) — `agenda:list`.
  - Event switcher — `events:listMine`.

## What's stubbed / next

- **Sign-in UI**: `SignInPlaceholderView` in `ContentView.swift` is a placeholder.
  Port Sentio's `SignInModal.swift` — it already drives ClerkKit's presentation flow
  against the same `Clerk.shared` instance this scaffold configures.
- **Live updates**: `ConvexClient` polls over HTTP rather than subscribing over
  WebSocket. Swap in `convex-swift` (get-convex's official client) for the same
  real-time push the webapp gets from `useQuery` — the function names/args don't change,
  only how the client is called.
- **Voice quality**: uses Apple's on-device `Speech` framework (zero extra deps). Sentio's
  app upgraded to WhisperKit for better accuracy fully offline — same upgrade path here
  once real organizers are testing voice input (see `VoiceCaptureService.swift`).
- **Push notifications**: `convex/notifications.ts` already has the data model; nothing
  wired to APNs yet.

## Setup

```bash
brew install xcodegen   # once
cp Config.xcconfig.example Config.local.xcconfig
# edit Config.local.xcconfig: CLERK_PUBLISHABLE_KEY (same as webapp's
# VITE_CLERK_PUBLISHABLE_KEY) and CONVEX_BASE_URL (same as VITE_CONVEX_URL)
xcodegen generate
open NamosSessions.xcodeproj
```

`Config.local.xcconfig` is gitignored — never commit real keys into it. Regenerate
`NamosSessions.xcodeproj` with `xcodegen generate` after editing `project.yml`; the
`.xcodeproj` itself isn't hand-edited or committed as source of truth — `project.yml` is.

## Why this scaffold, not a rewrite

`namos-sessions-webapp` already has an agent-native backend
(`convex/agentRuntime.ts`, `agentWorkflow.ts`, `agentRuns.ts`) built for the ChatGPT app
integration. Mobile doesn't need new business logic — it needs a voice-first UI in front
of functions that already exist and are already authorized per-event. That's the whole
reason this was a day's scaffold instead of a multi-week backend project.
