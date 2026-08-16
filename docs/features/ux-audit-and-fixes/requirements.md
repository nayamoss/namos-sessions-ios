# UX audit fixes — Agent screen redesign, New Task sheet, Dashboard empty states, Task Templates, person-linked tasks

**Type:** Bug (visual/UX) + Feature (Task Templates, person-linked task view)
**Status:** In Review
**Priority:** Critical — this is a direct response to a live walkthrough where every
screen checked had a real, visible problem. Nothing here is speculative.

## Problem Statement

A live walkthrough of the running app (Dashboard, Agent, New Task sheet) surfaced
real defects that written specs alone didn't catch — the gap between "matches the
written UI Spec" and "looks like a designed product" that got flagged earlier in this
project and then happened anyway. Two real backend-data features (Task Templates,
tasks filtered/grouped by person) also turned out to be completely missing from iOS
despite already existing server-side with zero new backend work required.

## Issue 1 — Dashboard: no context, no real empty states

Screenshot evidence: four tiles (Notifications, Tasks, Next, Check-in) all reading
`0` / `—` / `0 of 0`, no event name anywhere on screen, no explanation, no next action.

**Fix:**
- Add the current event's name as a persistent header/subtitle on the Dashboard —
  an organizer with more than one event has no way to know which one they're looking
  at otherwise.
- Every tile needs an actual empty state, not a raw zero: distinguish "genuinely
  nothing yet" from "no event data at all." E.g. Check-in should read "No speakers
  yet" (not "0 of 0") when the event has zero speakers, vs. a real count once it does.
- Confirm tiles are tappable and navigate to their related tab — this was speced but
  never visually confirmed; verify it for real this time, by actually looking at the
  navigation happen (see Verification section — this whole doc's fixes get a stricter
  bar than "it builds").
- Check-in's tile cannot show a real number until `feature/checkin`'s backend is
  merged to `main` (already flagged separately) — until then, this tile should say
  something honest like "Not available yet," not a fake "0 of 0" that looks like real
  data.

## Issue 2 — Agent screen: doesn't read as a chat screen at all

Screenshot evidence: a large dead void between a centered icon+caption and a bottom
input bar, with **three separate, visually undifferentiated voice affordances** on
screen at once (a circle waveform icon near the top, a mic button, and a waveform
button next to it at the bottom) — no way to tell what any of them does differently.
This is not a chat interface, it's an unfinished-looking placeholder.

**This needs actual design thinking, not a literal re-read of the old UI Spec.**
Direction:

- This is a chat screen. It should look like one: a message list area that fills the
  space between the header and the input bar (even empty, it should feel like "this
  is where a conversation will appear," e.g. a centered icon+caption *inside* that
  message area, not floating alone in a void with huge dead space above/below it).
- **One clear primary voice action, not three.** The existing push-to-talk mic and the
  newly-added ElevenLabs conversational entry point are two genuinely different modes
  (single-shot dictation vs. live back-and-forth) — that's a real distinction worth
  keeping, but it must be *obviously* two different things to a user, not two
  identical-looking circles next to each other. Consider: one primary mic button for
  push-to-talk (as today), and the conversational mode as a clearly labeled secondary
  entry point (e.g. a labeled button/pill, "Start voice chat," not an unlabeled icon
  indistinguishable from the mic).
- Keyboard/text-input toggle stays, but shouldn't visually compete with the voice
  controls for primary attention — text is the fallback path, not equal-weight.
- Reference point: this app already has a working design system (`NamosColor`, card/
  surface conventions) — the problem here isn't missing tokens, it's empty layout
  proportions and redundant controls. Fix the composition, not just the colors.

## Issue 3 — New Task sheet: blue buttons, dead space, unclear field

Screenshot evidence: "Cancel"/"Create" nav-bar buttons rendering in plain system blue
(direct violation — blue is banned everywhere in this app, this was missed because
`.navigationBarItems`/toolbar buttons don't automatically pick up `NamosColor.accent`
the way a custom `Button` view does — needs an explicit tint). Sheet has a small form
at the top and then a large empty void filling the rest of a full-height sheet — this
should be a compact, form-sized sheet (`.presentationDetents([.medium])` or similar),
not full screen with dead space below. The "FOR / Target [Contact ▾]" field is unclear
from the screenshot — confirm during the fix whether "Target" is meant to be an
editable field (contact name/search) or the picker is meant to swap between
target types (contact/group/submission/sponsor per `onboarding_tasks.targetType`) —
whichever it is, it needs a clear label distinguishing "what kind of task is this"
from "who/what it's for."

**Fix:**
- Explicit `.tint(NamosColor.accent)` on the New Task sheet's toolbar (same class of
  bug the tab bar had — check every other sheet/toolbar in the app for the same
  missing tint while this is being fixed, not just this one screen).
- Constrain the sheet to its actual content height (`.presentationDetents`), no dead
  space.
- Clarify and properly label the target-type/target-entity fields.

## Issue 4 — Task Templates missing entirely (real backend, zero iOS surface)

`taskTemplates:list` (args: `eventId`) returns an event's `task_templates` — each
with a `name`, `description`, and `items: [{ title, description?, targetType,
linkedFormId?, dueDateOffsetDays? }]`. `taskTemplates:applyToSubmission` and
`applyToSponsor` exist to bulk-create tasks from a template against a specific
submission/sponsor. **None of this is reachable from iOS today** — task creation is
always one-off freehand entry (per Issue 3's sheet). An organizer setting up
onboarding for a new speaker/sponsor has to write every task by hand on mobile even
though templates already exist for exactly this.

**Fix:** in the New Task flow (or a new entry point from Tasks/Speaker detail/Sponsor
detail), let the organizer pick a template (`taskTemplates:list`) and apply it
(`applyToSubmission`/`applyToSponsor` as appropriate) instead of only freehand entry.

## Issue 5 — No way to see tasks grouped/filtered by person

`onboarding_tasks` already has `speakerId`/`sponsorId` on every row and an index for
each (`by_speaker`, `by_sponsor`) — the data already ties every task to a person where
applicable. TasksView today shows a flat, undifferentiated list with no way to see
"what does Jane still owe me" or filter to one person's outstanding items.

**Fix:** add a way to view tasks scoped to a speaker or sponsor — at minimum, from a
speaker/sponsor detail screen, show their linked tasks; ideally also a filter/group-by
option on the main Tasks list itself. Use the existing `speakerId`/`sponsorId` fields
and indexes — no new backend needed.

## Out of Scope

- Redesigning screens not actually walked through and flagged (Tasks list layout
  itself, Agenda, Sponsors, Reviews) — this doc is scoped to what was actually shown
  to be broken, not a guess at everything else that might also need work.
- Building a full multi-select/bulk-apply-template UI — start with single-template
  application, matching what `applyToSubmission`/`applyToSponsor` already support.

## Success Metrics

- Every screen fixed here gets a real screenshot review (not just a passing build) as
  part of verification — this doc exists because "it builds" already proved
  insufficient once.
- Task Templates and person-linked tasks are reachable and usable, not just planned.
