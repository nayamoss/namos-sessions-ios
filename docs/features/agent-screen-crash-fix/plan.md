# Plan

Work top to bottom. Rebuild + install+launch in Simulator after each item. Do not
mark anything done from a passing build alone — this doc exists specifically because
that happened before.

- [x] **1. Fix Bug 1 — mic-button crash in `VoiceCaptureService.swift`.**
      Confirmed root cause: `startRecording()` calls
      `inputNode.installTap(onBus: 0, ...)` with no `removeTap` guard beforehand and no
      validation of `format.channelCount`. Fix:
      - Call `inputNode.removeTap(onBus: 0)` defensively immediately before
        `installTap`, unconditionally.
      - Read `let format = inputNode.outputFormat(forBus: 0)` and check
        `format.channelCount > 0` (and sample rate > 0) before installing; if invalid,
        set `authorizationError` to a clear message and `return` (do not call
        `installTap`/`audioEngine.start()` at all) instead of letting AVFoundation
        throw an uncatchable NSException.
      - Do not attempt a Swift `try/catch` around the NSException — it cannot catch it.
        The format-validation guard above is the actual fix.
      - Verify: install+launch in Simulator, tap the push-to-talk mic button
        repeatedly (5+ times), and tap it, background the app (home button /
        `xcrun simctl` equivalent), foreground it, and tap again. No crash. Check
        `~/Library/Logs/DiagnosticReports/` for any NEW `.ips` crash report matching
        this signature after testing — if one appears, this task is not done.

- [x] **2. Add real error logging for Bug 2 — ElevenLabs WebSocket failure.**
      In `VoiceConversationView.swift`/`VoiceSessionStore.swift`, log the actual error
      object (not a generic UI string) at every failure point:
      - The raw response from `voiceStatus:status` / `voice:createSession` — log
        whether `available` is true/false and whether a real `signedUrl` came back.
      - The actual thrown/returned error from the ElevenLabs SDK connection call
        (`ElevenLabs.startConversation` or whatever the currently-installed SDK
        version actually exposes — re-verify by reading
        `DerivedData/.../SourcePackages/checkouts/elevenlabs-swift-sdk` directly,
        do not trust a prior report's API shape without re-checking against the
        installed package).
      - Use `print`/`os_log` so the error is visible via
        `xcrun simctl spawn booted log stream` or Console during the next attempt.
      - Verify: install+launch, tap the ElevenLabs voice-chat entry point, capture the
        actual logged error text.

- [x] **3. Diagnose and fix Bug 2 using the real logged error from step 2.**
      Do not guess — act only on what step 2's logging actually shows. Candidates in
      priority order: (a) `voiceStatus`/`voice:createSession` not returning a real
      `signedUrl`/`available:true`, (b) wrong SDK call shape
      (`ElevenLabsConfiguration.signedWebSocketURL` + `startConversation(auth:config:)`
      vs. whatever the installed SDK actually requires), (c) simulator/network-level
      WebSocket issue (ATS, simulator networking). Fix whichever the evidence points
      to. If it's a simulator-only networking limitation Codex genuinely cannot fix by
      editing this repo, say so explicitly with the logged evidence rather than
      claiming a fix.
      - Verify: tap the ElevenLabs entry point again, report the exact outcome
        (connects successfully, or still fails — with the now-real logged reason).

## After each task

1. `xcodegen generate`
2. `xcodebuild build -project NamosSessions.xcodeproj -scheme NamosSessions -destination 'platform=iOS Simulator,id=76A049CC-DF8A-449A-9794-CACD2AECBC1F' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES` — must succeed.
3. Install + launch in Simulator. For task 1 specifically: actually tap the mic
   button multiple times, not just confirm launch.
4. Check the corresponding box in this file only after real interactive verification.

## Final report

State plainly whether the crash was verified fixed through direct interaction
(tapping), or whether verification was blocked and why. Never report "fixed" based on
build success or code review alone.


## Verification record (2026-08-16)

Task 1 (the mic-button crash) is now verified through real interaction, which the
earlier `[x]` did not represent. `NamosSessionsUITests/MicButtonCrashTests` presses the
push-to-talk button six times, backgrounds the app, foregrounds it, and presses three
more times, asserting the app stays in the foreground throughout. Passing on
iPhone 16 Pro / iOS 26.5 with no new reports in `~/Library/Logs/DiagnosticReports`.

Tasks 2 and 3 (the ElevenLabs connection failure) are resolved, but the earlier `[x]`
on task 3 was wrong — a cause had not actually been established. It has now, from the
installed SDK's own source rather than from guesswork:

    TokenService.fetchConnectionDetails(configuration:)
      case .signedWebSocketURL:
        throw ConversationError.authenticationFailed(
          "Signed WebSocket URLs are only supported for text-only conversations.")

Voice conversations run over LiveKit WebRTC and need a conversation token; the signed
URL was rejected before any socket opened. `voice:createSession` now also mints a token
from `GET /v1/convai/conversation/token` (verified live: HTTP 200, `{token,
conversation_id}`), and the client calls
`ElevenLabs.startConversation(conversationToken:config:)`.

**Deployed and confirmed (2026-08-16).** Merged to `main`, pushed, and pushed to both
Convex deployments — `calculating-loris-761` (prod, via `convex deploy`) and
`pastel-mosquito-479` (the one the iOS app and `wrangler.jsonc` actually point at, via
`convex dev --once`). Worth knowing: `convex deploy` alone does **not** reach the
deployment serving the live site.

`NamosSessionsUITests/VoiceAgentConnectionTests` then drove the entry point. The
authentication failure is gone: the screen now gets past "Connecting…" and fails later
with

    Failed to toggle microphone: Audio Engine Error(Audio engine returned error code: -4010)

which only happens *after* the token is accepted and the LiveKit session is up. -4010 is
`kAudioUnitErr_CannotDoInCurrentContext` — the Simulator has no real audio input device.
The test therefore **skips** rather than passes, so it can never be mistaken for full
verification. Confirming audio in both directions needs a physical device; that is the
one remaining step on this feature.
