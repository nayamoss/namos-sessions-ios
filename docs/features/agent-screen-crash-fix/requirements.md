# P0: Agent screen crash + ElevenLabs connection failure

**Type:** Bug — Critical
**Status:** In Review

## Bug 1 — App crashes (force-close) on the existing push-to-talk mic button

**Root cause confirmed from a real crash report**, not speculation — pulled directly
from `~/Library/Logs/DiagnosticReports/NamosSessions-2026-08-16-114028.ips`:

```
SIGABRT / uncaught NSException
AgentChatView.startTalking()
  → VoiceCaptureService.startRecording()
  → -[AVAudioNode installTapOnBus:bufferSize:format:block:]
  → AVAudioEngineImpl::InstallTapOnNode
  → AUGraphNodeBaseV3::CreateRecordingTap
```

This is the **existing** push-to-talk mic (`VoiceCaptureService.swift`, built earlier
in this project, not part of today's ElevenLabs work) — it is the button in the middle
of the Agent screen that force-closes the app when tapped. `installTapOnBus` throws an
NSException (not a Swift error — this is why nothing catches it) when: (a) a tap is
already installed on that node from a prior recording session that wasn't properly torn
down, or (b) the node's audio format is invalid at install time (zero channels, common
in Simulator when mic permission/hardware state is inconsistent between runs).

**Fix:**
- In `VoiceCaptureService.startRecording()`, call `removeTap(onBus: 0)` defensively
  before `installTapOnBus` — safe to call even if no tap exists, and this alone likely
  fixes the "already installed" case.
- Validate the input node's format before installing (check `format.channelCount > 0`);
  if invalid, fail gracefully into `authorizationError` (the property already exists on
  this service) instead of letting the SDK throw.
- Wrap the install call so a thrown NSException cannot propagate to a crash — Swift
  can't `catch` NSException directly, so this needs either the format-validation guard
  above to prevent the throw in the first place (preferred), or an Objective-C shim if
  AVFoundation genuinely has no safe path here. Preventing the throw is the real fix;
  do not paper over it with a try/catch that can't actually catch this exception type.
- Test by tapping the mic button repeatedly, and tapping it, backgrounding the app, and
  returning — the exact repro conditions for a stale tap.

## Bug 2 — ElevenLabs voice chat shows "Connecting…" then fails with a WebSocket error

Symptom reported directly: tapping the new voice-chat entry point shows "Connecting…"
and then fails, reporting a WebSocket issue. **Root cause not yet confirmed** — the
app currently has no logging of the actual error reason, so this cannot be diagnosed
further without first adding visibility. Do not guess at a fix before that.

**Required first step:** add real error logging in `VoiceConversationView`/
`VoiceSessionStore` — print/log the actual error object from the SDK's connection
failure (not just a generic "Connection issue" UI string) so the real cause is visible
in Console/simctl logs on the next attempt.

**Likely candidates to check, in order:**
1. `voiceStatus:status` / `voice:createSession` — confirm these are actually returning
   `{ available: true }` and a real `signedUrl` (not silently falling into the
   `unavailable`/error branch that the UI might be mis-rendering as "Connecting…"
   forever instead of showing the unavailable state). Log the raw response.
2. The resolved SDK call itself — a prior report documented
   `ElevenLabsConfiguration.signedWebSocketURL(signedUrl)` +
   `ElevenLabs.startConversation(auth:config:)` as the real API found by reading the
   SDK source. Re-verify this against the actual installed package version by reading
   `DerivedData/.../SourcePackages/checkouts/elevenlabs-swift-sdk` directly again —
   don't trust the earlier report without re-checking, since this is exactly the kind
   of thing that's easy to get subtly wrong (wrong auth type, wrong config default).
3. Network/simulator-specific WebSocket issues (e.g. ATS, simulator network path) —
   only worth chasing after 1 and 2 are ruled out with real logged evidence.

## Verification (both bugs)

- Install+launch in Simulator, tap the push-to-talk mic button — must not crash,
  repeatedly, including after backgrounding/foregrounding.
- Tap the ElevenLabs voice-chat entry point — capture and report the actual logged
  error if it still fails; do not report this "fixed" without either a working
  connection or, at minimum, a clearly identified real root cause with evidence.
- This is a P0 correctness bug, not a cosmetic one — do not report success from a
  build succeeding alone. Actually tap both buttons and observe real behavior,
  screenshot or describe exactly what happens.
