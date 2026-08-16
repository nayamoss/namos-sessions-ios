# Complete the Namos Sessions iOS scaffold

## Context

`namos-sessions-ios/` is a fresh XcodeGen-generated iOS scaffold (SwiftUI, iOS 17+) for
`namos-sessions-webapp` — a conference/event organizer platform (Convex backend + Clerk
auth). It reuses proven patterns from the Sentio iOS app
(`../../sentio-main/sentio-v2/sentio-ios-app-v2/`), which has a mature Clerk auth
bootstrap, voice/transcription services, and a design system already shipping in
production.

**Verified working right now:**
- `xcodebuild build -project NamosSessions.xcodeproj -scheme NamosSessions -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` succeeds.
- Installs and launches clean in iOS Simulator (confirmed via `xcrun simctl install`/`launch` — no crash, shows "Configuration needed" placeholder because `Config.local.xcconfig` ships with an intentionally blank `CLERK_PUBLISHABLE_KEY`).
- `ConvexClient.swift` calls the real Convex HTTP API (`/api/query`, `/api/mutation`, `/api/action`) against `namos-sessions-webapp`'s existing Convex functions — no new backend.
- Three screens wired to real Convex functions: Agent Chat (`convex/agentRuns.ts`: `create`/`respond`/`get`), Tasks (`convex/tasks.ts`: `list`/`setStatus`), Agenda (`convex/agenda.ts`: `list`, read-only). Event switcher uses `convex/events.ts`: `listMine`.
- Voice input via Apple's native `Speech` framework (push-to-talk in `VoiceCaptureService.swift`).

**Read `namos-sessions-ios/README.md` first** — it documents what's real vs. stubbed and why (e.g. why `ConvexClient` polls over HTTP instead of a WebSocket client, why voice uses `Speech` not WhisperKit yet).

**IMPORTANT — a real crash was already found and fixed once**: `Clerk.configure()` in
ClerkKit only validates key format at a deep internal step (base64-decoding whatever
follows `pk_test_`/`pk_live_`) and crashes via `assertionFailure` (Debug builds only) if
that fails. Do not add a "smarter" pre-validation regex that tries to fully replicate
Clerk's internal logic — it's brittle and could drift from the SDK. The safe pattern
already in place: `ClerkAuthManager.configure()` only checks for an empty string, and
`Config.xcconfig.example` ships the key blank on purpose. Keep that pattern for any
other externally-configured credential you touch (Convex URL, etc.) — fail visibly and
gracefully on missing config, don't try to out-guess a third-party SDK's validation.

## Task

Work through `plan.md` in this same folder. Each item is independently shippable —
check them off as you go, don't try to do them as one giant commit.

## Acceptance criteria

- `xcodebuild build` still succeeds after every change (run it after each task).
- The app still installs and launches without crashing in iOS Simulator (verify with
  `xcrun simctl install` / `xcrun simctl launch --console` — the console output must show
  no `Fatal error` line) after every task that touches app startup or the Info.plist.
- No new SPM dependency is added without checking `Package.resolved` first — prefer
  what's already resolved (ClerkKit's transitive deps: Nuke, PhoneNumberKit) unless the
  task explicitly calls for a new package (e.g. convex-swift).
- Real secrets never get committed. `Config.local.xcconfig` is gitignored — leave it that
  way, and never put a real key inline in a Swift file or a committed config.
