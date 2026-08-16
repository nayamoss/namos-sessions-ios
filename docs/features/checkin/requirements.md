# Speaker check-in — schema proposal (needs your yes before anything is built)

## Why this is a separate field, not reusing `confirmationStatus`

`speakers.confirmationStatus` (`awaiting`/`confirmed`/`declined`) is a pre-event RSVP —
whether a speaker agreed to show up at all. Day-of check-in ("they physically arrived")
is a different fact with a different lifecycle: a speaker can be `confirmed` for weeks
and still not check in until the morning of. Overloading one field for both would make
`confirmationStatus` lie the moment someone confirms in advance but the organizer wants
to track arrival separately — so this is additive, not a repurpose.

## Proposed change

Add to the existing `speakers` table in `convex/schema.ts` (no new table needed):

```ts
checkedInAt: v.optional(v.number()),   // undefined = not checked in yet
checkedInByUserId: v.optional(v.string()),  // which organizer/reviewer checked them in
```

Plus one new index: `.index("by_event_checkedIn", ["eventId", "checkedInAt"])` — lets a
"who's still not here" view query cheaply.

## Proposed mutations (new `convex/speakerCheckIn.ts`, or added to `speakers.ts` —
your call, following whichever file-size convention the codebase already leans toward)

- `checkIn(speakerId)` — sets `checkedInAt`/`checkedInByUserId`, organizer-only
  (`assertEventOrganizerAccess`, same guard every other event-scoped mutation uses).
- `undoCheckIn(speakerId)` — clears both fields, for the "wrong tap" case.

## iOS side (not built until this is approved)

New screen or a mode within an existing one — TBD pending your answer below. Options:
- **A. New 4th/5th tab** — "Check-in": full-screen list of today's speakers, tap to
  toggle checked-in, search/filter by "not yet arrived."
- **B. Folded into Agenda** — a checked-in indicator + tap target on each agenda row's
  speaker, no new tab.

A leans toward a dedicated at-the-door workflow (scan the list fast, work through it).
B keeps the tab count down and ties check-in to "who's in this session," which matters
less for door check-in and more for room-level tracking. I'd default to A unless you
tell me check-in actually happens per-session rather than per-event.

## Decision (approved)

1. Schema approved as proposed above.
2. Option A — dedicated "Check-in" tab, full-screen list of today's speakers, tap to
   toggle, search/filter "not yet arrived."

## User journey — Check-in tab

**Entry point:** New tab, "Check-in" — checkmark/person icon, added alongside the
existing Agent/Tasks/Agenda tabs in `ContentView.swift`.

**Main state:** Full list of the event's speakers (`speakers:list`-equivalent — confirm
exact query name before building, don't assume), each row showing name, headshot if
present, and a checked-in toggle. Not-yet-arrived speakers sort to the top by default.

**Search/filter:** Text search by name (client-side filter on the already-loaded list —
event speaker counts are small enough that a server-side search query is unnecessary
here). A segmented control or toggle: "All" / "Not checked in."

**Tap behavior:** Tapping a row's toggle calls `checkIn`/`undoCheckIn` immediately
(optimistic update, same pattern as `TasksViewModel.toggleComplete`) — no confirmation
dialog, since undo is one tap away and this is meant to be fast at a door.

**Empty state:** "No speakers for this event yet." (matches existing empty-state tone).

**Live updates:** `ConvexLiveClient` subscription on the speakers-with-checkin query, so
two organizers checking people in at different doors see each other's updates.

**Out of scope for this pass:** attendee (non-speaker) check-in — this schema only
covers `speakers`, not a general attendee list, which doesn't exist in the schema
today and would be its own confirm-first decision if ever needed.
