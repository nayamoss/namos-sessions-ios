# Handoff — Namos Sessions iOS / Convex

Everything below is unfinished. Everything *not* below is done, pushed, and verified.
Copy the "Prompt for the next agent" section into a fresh session.

## State as of 2026-08-16 (all pushed, nothing local-only)

- `namos-sessions-ios` — **new private repo**: https://github.com/nayamoss/namos-sessions-ios
  `main` = `dev` on origin. Before today this folder had no git history at all.
- `namos-sessions-webapp` — `main` = `dev` = `origin/main` = `origin/dev` = `22b2b1a`.
- Convex: deployed to **both** `calculating-loris-761` (prod) and `pastel-mosquito-479`.
- Test suite: 4 XCUITests, 3 passing, 1 skipping for a documented hardware reason.

## Prompt for the next agent

> You are picking up the Namos Sessions iOS app (`namos-sessions-ios`, private repo,
> current `main`) and its Convex backend (`namos-sessions-webapp`, `main` at
> `22b2b1a`). Both are fully pushed and in sync; no merges are pending.
>
> Before you touch anything, read these two things — they encode why previous sessions
> reported work as done when it wasn't:
> - `docs/features/ux-audit-and-fixes/plan.md` (verification record at the bottom)
> - `docs/features/agent-screen-crash-fix/plan.md` (verification record at the bottom)
>
> **Rule that matters most here:** on this Mac, `osascript`/System Events cannot drive
> the Simulator ("osascript is not allowed assistive access"), so host-side tap
> automation always fails. Verify by writing or extending an **XCUITest** in
> `NamosSessionsUITests/` — it drives the Simulator from the inside and needs no
> Accessibility grant. Run the suite with:
>
> ```
> cd namos-sessions-ios
> xcodebuild test -project NamosSessions.xcodeproj -scheme NamosSessions \
>   -destination 'platform=iOS Simulator,id=76A049CC-DF8A-449A-9794-CACD2AECBC1F' \
>   -only-testing:NamosSessionsUITests
> ```
> Never report something as working off a passing `xcodebuild build`. If the Simulator
> genuinely cannot exercise something, `throw XCTSkip` — do not assert success.
>
> Work these in order:
>
> **1. (P0, needs a physical iPhone) Confirm ElevenLabs voice audio end to end.**
> Everything up to audio is already proven working: `voice:createSession` mints a
> LiveKit conversation token, the token is accepted, and the LiveKit session is
> established. On the Simulator it then fails at
> `Audio engine returned error code: -4010` (`kAudioUnitErr_CannotDoInCurrentContext`)
> because there is no real microphone. `VoiceAgentConnectionTests` currently *skips* on
> exactly that string. Deploy to a real device, open Agent → "Start voice chat", and
> confirm you can hear the agent and it can hear you. If it fails on device, the error
> will be genuinely new — read it before changing anything, and note that
> `VoiceSessionStore` already logs the real error objects.
>
> **2. Decide the two-Convex-deployment split.** [Update 2026-08-17: full writeup now in
> `namos-sessions-webapp/docs/deployment/production.md` — read that instead of re-deriving this.
> Short version: `calculating-loris-761` is Convex's own designated "production" deployment but
> holds only 3 stale seed events; `pastel-mosquito-479` is labeled a personal dev deployment but
> holds 100% of the real live data and is what `wrangler.jsonc`/`.env.local`/iOS actually point
> at. Bare `npx convex deploy` targets the empty one, silently. This has already bitten two agent
> sessions in one night (deleted/recreated indexes on the wrong deployment, no data lost both
> times because it was caught before a Worker deploy). Push functions with
> `CONVEX_DEPLOYMENT="dev:pastel-mosquito-479" npx convex dev --once`, never bare `convex deploy`.
> The actual topology decision — repoint which deployment is "production", or retire/rename
> `calculating-loris-761` — is still open and needs Naya, not an agent, to decide.]
>
> `npx convex deploy` targets `calculating-loris-761`, but `wrangler.jsonc`
> (`VITE_CONVEX_URL`), `.env.local`, and the iOS app's `CONVEX_BASE_URL` all point at
> `pastel-mosquito-479`. So `convex deploy` alone does **not** update the backend serving
> the live site — you must also run `npx convex dev --once`. A comment in `.env.local`
> claims "one deployment for everything", which is wrong. Either repoint everything at
> one deployment or document the split; right now it is a trap.
>
> **3. Convex is approaching Free plan limits.** The CLI warns "consider upgrading to
> avoid service interruption" on every deploy. Check the dashboard and tell Naya whether
> this is about to break production.
>
> **4. Confirm live Convex subscriptions deliver after the JWT-template correction.**
> The old `ClerkConvexAuthProvider` requested Clerk's default JWT, while both the backend
> and the HTTP client require Clerk's explicitly named `convex` template. It has been
> replaced with `ConvexTemplateAuthProvider`, which asks for that same template, and the
> obsolete `clerk-convex-swift` dependency was removed. `TasksViewModel` now logs both a
> delivery and a subscription failure to make this observable. The full XCUITest suite
> passes, but it cannot distinguish WebSocket data from the HTTP seed; confirm one real
> delivery in Console/Xcode (or add a focused test that performs a separate write).
> Do not remove the HTTP seed — it remains the resilience path if the socket is unavailable.
>
> **5. T014 — voice-triggered subagent.** Deliberately unbuilt, pending Naya's sign-off.
> Do not start it without asking.
>
> Smaller follow-ups, only if there is time:
> - `PersonTasksView` covers speakers and sponsors. Template apply is wired for sponsors
>   only, because the server's other entry point (`taskTemplates:applyToSubmission`) keys
>   off a submission, not a speaker. A submission-side entry point in `SubmissionsView`
>   would close the gap.
> - The main Tasks list still has no group-by-person filter; the audit called that the
>   "ideally also" half of Issue 5.
> - `tasks:list` has no `sponsorId` argument, so sponsor tasks are filtered client-side.
>   Fine at current data volumes; add a server-side filter if sponsor counts grow.
>
> House rules that apply: never make a repo public; no blue buttons (use
> `NamosColor.accent`); never touch Convex schema/migrations without confirming with Naya
> first; batch commits and push once rather than pushing repeatedly to auto-deploying
> branches; log remaining work in `/Users/nieoln/GitHub/sites/naya-project-todos/todo.md`.

## Branch bookkeeping done today

Nothing was deleted. Preserved on `origin`:
- `backup/concurrent-wip-2026-08-16` — another session's uncommitted publishing work
  (`AGENTS.md`, `docs/PUBLISHING.md`, `scripts/publish/`, `CONTRIBUTING.md`,
  `package.json`) plus the regenerated `convex/_generated/api.d.ts`. Their working tree
  was left untouched; the snapshot was built through a throwaway index.
- `archive/feat-60-local-2026-08-16`, `archive/improvement-67-local-2026-08-16` — local
  branches whose history had diverged from their remote namesakes. Archived under new
  names rather than force-pushed, so no remote commits were destroyed.
- `feat/agent-dictation` — holds the dictation commit that `feature/checkin` was
  accidentally stacked on. Only the check-in schema commit was cherry-picked onto `main`;
  the dictation work was **not** merged and still needs review.
