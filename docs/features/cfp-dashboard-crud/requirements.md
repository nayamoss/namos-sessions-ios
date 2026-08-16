# CFP review queue, Dashboard, Speaker CRUD, Sponsor CRUD

Planning only — grounded in real Convex signatures read directly from
namos-sessions-webapp/convex/ (not invented). Approved sequence, build in this order.
Same rule as every prior feature here: no implementation until a subagent delegates it
to Codex and verifies with a real `xcodebuild` + simulator launch — no code from the
planning pass itself.

---

## 1. CFP / Submissions review queue (build first — biggest net-new value)

**Real backend, already exists:**
- `evaluations:myQueue` (args: none) — the signed-in reviewer's own assignment queue.
- `evaluations:save` (args: `id?`, `assignmentId?`, `eventId`, `submissionId`,
  `reviewerName`, `score?`, `comments?`, `criteriaScores?`) — submits a score. When
  `assignmentId` is present, auth is anchored to the assignment's `reviewerUserId`
  (Clerk identity), not the client-supplied `reviewerName` — never let the UI send a
  spoofable identity.
- `evaluations:listPlans` (args: `eventId`) — organizer-only, gives the scoring
  criteria/scale for the event (`evaluationCriterion[]`, `scoringScaleMax`).
- `submissions:decide` (args: `submissionId`, `status`: `"accepted"` | `"declined"`) —
  organizer-only accept/decline.
- `submissions:list` (args: `eventId`, `speakerId?`) — organizer sees the whole event's
  submissions; omit `speakerId` for that.

**User journey — two roles, two screens (or one screen with mode based on role):**

*Reviewer mode (`evaluations:myQueue`):*
- List of assigned submissions to score, each showing title + status.
- Tap → scoring sheet: renders the event's criteria (from the plan tied to the
  assignment — fetch via the assignment's `evaluationPlanId`), one input per criterion
  (`number` criteria show a stepper/slider up to `max`; `text` criteria show a text
  field), plus overall comments. Submit calls `evaluations:save`.
- This is the actual "review talks during your commute" workflow — the whole reason
  this got prioritized first.

*Organizer mode (`submissions:list` + `submissions:decide`):*
- List of all submissions, status badge, filter by status (at minimum
  `pending`/`accepted`/`declined` — the other statuses like `accept_queue` are
  in-flight webapp workflow states, don't need their own filter chip on mobile).
- Tap → detail view (title, answers — render `answers` generically since it's `v.any()`
  keyed by the form's fields, don't hardcode field names) with Accept/Decline actions
  calling `submissions:decide`.

**Out of scope for this pass:** drafting/editing a submission's answers, submission
form (CFP) creation/editing (that's authoring a form, not managing responses — stays a
webapp-only task), bulk operations, tag/track assignment from mobile.

---

## 2. Dashboard / home screen (build second)

**Explicitly NOT a copy of the webapp's dashboard** — that one opens with a greeting
("Good morning"), agent suggestions, and prose. Naya's own standing design preference
(see dashboard-design-preference memory) is spare, no date/greeting/narrative text.
Mobile dashboard is stats only:

- Unread notifications count (already have `notifications:unreadCount`)
- Pending tasks count (`tasks:list`, filter client-side or note if a count-only query
  would be cheaper — check before assuming `list` is fine for a badge)
- Now/next agenda item (`AgendaViewModel.happeningNow`, already built)
- Review queue size, if the signed-in user has one (`evaluations:myQueue`)
- Check-in progress ("12 of 30 speakers checked in" — `speakers:list` filtered by
  `checkedInAt`)

Each stat is a tappable tile that jumps to its tab. This becomes the app's actual
landing screen post-sign-in (replacing "lands on Agent tab" as the default first tab).

**Out of scope:** charts/graphs, historical trends, anything requiring new backend
aggregation — every number here comes from an existing query, just counted/filtered
client-side.

---

## 3. Speaker CRUD (build third)

**Real backend, confirmed:** `speakers:create` (args: `eventId`, `firstName`,
`lastName`, `email`, `confirmationStatus?`). `speakers:updateProfile` was checked
directly — it is **self-service only** (gated by `scopedOwnedSpeaker`, the speaker
editing their own portal record), not organizer-callable. There is no existing
organizer-side "edit a speaker's name/email" mutation — this is a real, confirmed gap.

**New backend surface required (small, additive, no schema change):** a
`speakers:organizerUpdate` mutation — args `eventId`, `speakerId`, `firstName`,
`lastName`, `email`, `confirmationStatus?`, gated by `assertEventOrganizerAccess` (same
guard `checkIn`/`checkIn` already use). This is new mutation logic, not a schema/table
change, so it doesn't need the same stop-and-confirm gate a new field/table does — but
it's called out explicitly here rather than silently added, per how every other backend
change in this app has been logged.

**User journey:** From the Check-in tab (or a new Speakers list), a "+" button opens a
create sheet: first name, last name, email, confirmation status picker. Save calls
`speakers:create`. Tapping an existing speaker opens the same sheet pre-filled, calling
the new `speakers:organizerUpdate`.

**Out of scope:** bio, socials, headshot upload (`requestHeadshotUpload`/`saveHeadshot`
exist but are a bigger file-upload flow — not "on the go" core), bulk import.

---

## 4. Sponsor CRUD (build fourth)

**Real backend, confirmed:**
- `sponsors:create` (args: `eventId`, `name`, `tierId?`, `status`, `website?`, `notes?`)
- `sponsors:update` (args: `sponsorId`, all other fields optional)
- `sponsors:remove` (args: `sponsorId` — cascades: checks `sponsor_contacts`, tasks,
  submissions, forms tied to the sponsor before deleting, per the webapp's own guard)
- `sponsors:list`, `sponsors:get`
- `sponsors` schema: `name`, `status` (`prospect`/`confirmed`/`declined`), `tierId?`
  (→ `sponsor_tiers`), `website?`, `notes?`. Flat and simple — no surprise complexity.
- `sponsor_contacts` is a separate table (name/email/phone/role/isPrimary per sponsor)
  — genuinely useful ("who do I call at this sponsor") and simple enough to include as
  a secondary screen within this same task, not a reason to delay sponsor CRUD.

**User journey:** List + create/edit sheet (name, tier picker from
`sponsorTiers:list`-equivalent — confirm exact query name when building, tier is
optional so don't block save on it, status, website, notes). `remove` is destructive —
require a confirm step (iOS alert), not a bare tap, since it cascades. Tapping into a
sponsor shows its contacts with a lightweight add-contact sheet.

**Out of scope:** sponsor tier authoring itself (creating/reordering tiers is
event-setup, desk-bound), anything from `sponsorTiers.ts` beyond reading the list to
populate the picker.

---

## Audit: everything else in convex/, and why it's out of scope

Full inventory checked (`ls convex/*.ts`) against the "manage on the go" bar. Logged
explicitly rather than silently skipped:

- **`comms.ts`/`commsData.ts`/`emailDelivery.ts`/`emailIntegrations.ts`** — email
  campaign/template authoring. Desk-bound composition task, not a quick mobile action.
- **`eventMembers.ts`** — inviting/removing organizers/reviewers. Sensitive
  (grants access) and email-entry-heavy; better done at a desk with full context, not a
  quick mobile add. Revisit only if a real "invite a reviewer right now" moment comes up.
- **`apiKeys.ts`** — developer/integration config, purely desk-bound.
- **`forms.ts`/`formTemplates.ts`/`publicForms.ts`** — CFP *form* authoring (building
  the submission form itself). Already correctly scoped out under item 1 above —
  reviewing/deciding on responses is mobile-relevant, building the form that collects
  them is not.
- **`tags.ts`** — minor tagging utility, low value standalone, skip until something
  else needs it.
- **`speakerDocuments.ts`** — file/document management, real file-upload UX work, not
  "on the go" core.
- **`taskTemplates.ts`**, **`categoryRouting.ts`** — event-setup-time configuration,
  not day-of organizer actions.
- **`userProfiles.ts`/`organizations.ts`/`organizers.ts`** — account and *role*
  administration. Explicitly not touching this from mobile — role/owner assignment is
  exactly the kind of thing that stays database-backed and deliberately administered,
  not something to make quick-tappable.
- **`voice.ts`/`voiceStatus.ts`** — the webapp's own server-side dictation transcription
  (browser mic → OpenAI). Not a gap — iOS already does this better, on-device, via
  `VoiceCaptureService.swift`'s native Speech framework, no server round trip needed.
- **`availability.ts`** — speaker scheduling availability input; feeds agenda conflict
  detection already reused in the Agenda edit feature, no standalone mobile need found.

Nothing above is being silently dropped — each has a reason. If any of these turn out
to matter for a specific on-the-go moment later, that's a new planning pass, not a
retrofit.
