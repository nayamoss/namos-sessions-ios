# CFP Voice Digest — hands-free submission review

Planning only. This is an ADDITIVE mode on top of the CFP review queue already being
built (docs/features/cfp-dashboard-crud/requirements.md, item 1) — not a replacement,
and deliberately queued to start only after that base screen lands, since a second
subagent building on the same files in parallel would collide with the one already
running. Same rule as everything else here: no code until delegated to Codex and
verified with a real build + simulator launch.

## The idea (from Naya)

Organizer taps into "Listen" mode from the submissions queue. The app reads submissions
out loud, one after another, podcast-style: speaker name → bio → submission title →
submission answers. Skips social links/URLs — not useful spoken. Swipe or tap to
accept/decline while listening, auto-advances to the next one. With 100 submissions,
this turns a sit-down desk task into something done on a walk or a commute.

## Scope clarification (important, not in the original ask — flagging explicitly)

"Approve/disapprove" here maps to `submissions:decide` (organizer accept/decline) —
the fast binary triage path, NOT the detailed multi-criteria reviewer scoring sheet
(`evaluations:save`) already planned separately. Those are different jobs: scoring
against rubric criteria doesn't reduce to a swipe gesture. Voice Digest is for the
organizer's own first-pass triage; the reviewer scoring queue stays a sit-down task.

Adding a third gesture beyond the two you described, because forcing a binary decision
on every submission after one listen is a worse experience than what you asked for:
**swipe right = Accept, swipe left = Decline, tap "Flag" = skip/defer without deciding**
(stays `pending`, comes back in a future digest session). This is the one place I'm
extending your spec rather than just implementing it literally — flagging it as such
rather than quietly adding it.

## User journey

**Entry point:** "Listen" button on the CFP review queue screen (organizer mode).

**Playback:**
- Sequential queue = `submissions:list` filtered to `pending` status.
- Per submission, `AVSpeechSynthesizer` (on-device, free, no new API/dependency —
  matches this app's existing voice pattern of staying on-device, see
  `VoiceCaptureService.swift`) reads, in order: speaker's name → bio (if present) →
  submission title → submission answers (iterate the `answers` object's text values;
  `answers` is `v.any()` keyed by the form's fields — read field values generically,
  don't hardcode field names, same caution as the tap-based review screen).
- Auto-advances to the next submission when speech finishes, unless paused.

**Controls (on-screen, large touch targets — usable without looking, since the point is
not looking at the phone):**
- Swipe right / big checkmark button → `submissions:decide(accepted)`, advance.
- Swipe left / big X button → `submissions:decide(declined)`, advance.
- "Flag" button → leave status as `pending`, advance (comes back next digest session).
- Play/pause, skip-forward (re-triggers current item's speech from start), skip-back.

**Background/lock-screen behavior (this is what makes it actually "podcast-style"):**
- `AVAudioSession` category `.playback` so it keeps talking with the screen off or app
  backgrounded — a real requirement for "on a walk," not just a nice-to-have.
- `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` for lock-screen/Control-Center
  play/pause/skip — same system organizers already know from any podcast app.
- Accept/decline from the lock screen is explicitly OUT of scope for v1 — those are
  data-mutating actions and deserve the app open and visible, not a blind lock-screen
  tap. Pause/resume/skip-through only from the lock screen.

**Empty state:** "No pending submissions to review." (if the queue is empty when
Listen mode is opened).

**Interruption handling:** a phone call or another app's audio should pause playback
cleanly (standard `AVAudioSession` interruption handling) and resume-on-return, not
crash or silently drop the queue position.

## Out of scope for v1

- Reviewer-mode criteria scoring via voice (stays the tap-based scoring sheet).
- Speed/voice controls (1x/1.5x, voice selection) — nice-to-have, not core.
- Reading social links, headshots, or any non-text field.
- Lock-screen accept/decline actions (see above).
- Resuming a specific submission mid-queue after fully closing the app — v1 always
  starts the digest from the top of the current pending queue.

## Dependencies

Needs the base CFP review queue (`submissions:list`, `submissions:decide`) already in
progress. Do not delegate this to Codex until that work is verified complete — same
`ContentView.swift`/shared-model collision risk that's already been hit twice with
parallel Codex jobs applies here too.
