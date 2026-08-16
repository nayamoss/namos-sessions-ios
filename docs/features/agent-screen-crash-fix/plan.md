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
