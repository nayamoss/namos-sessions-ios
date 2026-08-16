# Notifications inbox + Live agenda edit — user journeys

Planning only. No implementation until this is approved; then hand to Codex (model
gpt-5.6-terra, medium effort) via a supervised subagent — not built inline.

Grounded in what already exists server-side (checked directly, not assumed):
- `convex/notifications.ts`: `list`, `unreadCount`, `markRead`, `markAllRead` — all exist.
- `convex/agenda.ts`: `save`, `detectConflicts` — both exist, same conflict logic the webapp uses.

---

## 1. Notifications inbox

**Why this first:** APNs device registration already ships in the app (today's push
notification work) with nowhere for the organizer to actually see what was pushed. This
closes that loop — it's the most-done, least-new-scope item on the list.

**Entry point:** New 4th tab, "Notifications" — bell icon, matching the existing
Agent/Tasks/Agenda tab pattern in `ContentView.swift`. Badge on the tab icon shows
`unreadCount` (already a live query, no polling math needed).

**Main state — list view:**
- One row per notification: `title`, `body` (if present), relative timestamp, unread
  dot if `readAt` is unset.
- Sorted by `createdAt` desc (matches `by_recipient` index).
- Tap a row → `markRead`, then navigate using `linkPath` if present. `linkPath` values
  point at webapp routes (e.g. `/events/:id/submissions/:id`) — for v1, iOS doesn't have
  matching in-app routes for most of these, so tapping shows the notification's full
  `title`/`body` in a detail sheet instead of deep-linking. Deep-linking into the right
  iOS screen (e.g. a `submission_received` notification opening... there's no
  Submissions screen in iOS yet) is future scope, not this pass.
- "Mark all read" button in the nav bar → `markAllRead`.

**Empty state:** "No notifications yet." — same tone/style as the empty states already
in TasksView/AgendaView.

**Error state:** Same pattern as existing screens — inline error text, `.refreshable`.

**Live updates:** Use `ConvexLiveClient` (already wired for Agent/Tasks/Agenda) for
`notifications:list` and `notifications:unreadCount` — a push notification arriving
should update the badge without a manual refresh.

**Out of scope for this pass:** notification preferences/settings, push-triggered deep
links into screens that don't exist yet in iOS, grouping/filtering by `kind`.

---

## 2. Live agenda edit

**Why second:** Today's `AgendaView` is read-only. The webapp's edit logic
(`agenda:save` + `agenda:detectConflicts`) already does the hard part (room/speaker/
track overlap detection) — iOS just needs a UI in front of it, not new logic.

**Entry point:** Tap an agenda row in the existing `AgendaView` → edit sheet. Keep the
existing "Now" banner and read-only list as-is; editing is additive.

**Edit sheet fields (matches `agendaItemFields` in `convex/agenda.ts`):**
- Title (text)
- Room (picker — needs `rooms:list`-equivalent; confirm this query exists before
  building, don't assume)
- Start time / end time (date pickers)
- Published toggle

Deliberately **excluded from v1**: track assignment, speaker reassignment, video URL,
location details free-text. Those are lower-frequency edits better done at a desk on
the webapp — v1 covers the "I'm standing in the hallway and the room just changed"
case specifically, not full agenda authoring.

**Conflict handling:** Before saving, call `agenda:detectConflicts` with the pending
change. If it returns a conflict (room/speaker/track overlap), show it inline in the
sheet and require the organizer to acknowledge or cancel — never silently save over a
conflict. This mirrors how the webapp itself gates the same mutation.

**Save flow:** Optimistic update in the list (same pattern `TasksViewModel.toggleComplete`
already uses), roll back on mutation failure.

**Empty/error states:** Reuse existing `AgendaView` empty/error patterns.

**Out of scope for this pass:** creating new agenda items from iOS, deleting items,
publishing/unpublishing the whole schedule (`publishSchedule` exists server-side but is
a bigger, riskier action — better left to the webapp for now).

---

## Resolved before build

Room picker query confirmed: `events:listRooms` (`convex/events.ts:389`). No open
questions left blocking Codex on this pair of features.
