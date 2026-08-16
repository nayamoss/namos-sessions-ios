# Settings screen + tab overflow fix — Requirements

**Type:** Bug (tab overflow) + Feature (Settings screen)
**Status:** In Review
**Priority:** High — the overflow bug is a visible design-system violation in the shipped app right now.

## Problem Statement

1. **Bug:** `ContentView.swift`'s `TabView` now has 8 tabs (Dashboard, Agent, Tasks,
   Agenda, Check-in, Speakers, Reviews, Sponsors — plus Notifications). iOS's default
   `TabView` behavior auto-collapses anything past 5 into its own system-provided
   "More" list — confirmed via screenshot: plain white background, blue-tinted SF
   Symbols, standard list rows. This is entirely outside this app's design system (no
   `NamosColor`, and blue is explicitly banned everywhere in this app). Not a
   theoretical concern — it's what real device/simulator screens look like right now.
2. **Feature:** No Settings screen exists at all — no way to see the signed-in
   account, sign out, see which event is selected, or toggle notification
   preferences. Every other iOS app in Naya's portfolio (Sentio) has one; this app
   doesn't.

## Reference pattern (not a verbatim port)

Sentio's `SettingsView.swift` (`sentio-ios-app-v2/SettingsView.swift`, 2457 lines) has
far more than this app needs — subscriptions/StoreKit, third-party integrations
(Notion/Obsidian/Medium/Ghost/Substack/Zapier/webhooks), writing personas, on-device
LLM, weekly digest. None of that applies here. What's actually reusable is the
*section structure*: Account (signed-in identity + sign-out confirmation dialog),
General (appearance/color-scheme picker via `AppStorage`), Legal/About, Danger Zone
pattern (confirm → confirm-again for destructive actions). This app already has the
exact building block Sentio's Account section needs —
`ClerkAuthManager.signOut()` — reuse it directly, don't reinvent.

## Functional Requirements

- FR-001: Restructure `ContentView.swift`'s tabs so nothing relies on iOS's default
  "More" overflow — either reduce visible tabs to 5 or fewer (Dashboard, Agent, Tasks,
  Agenda, and one custom-styled "More"/Settings entry that itself lists the rest in an
  in-app, `NamosColor`-styled list — not the system default).
- FR-002: New Settings screen: Account section (signed-in email from
  `ClerkAuthManager`, current event name, sign-out button with confirmation dialog),
  Appearance section (light/dark/system picker, `AppStorage` pattern matching
  Sentio's), Notifications section (toggle — ties into the already-built APNs
  registration/`DeviceTokenManager`), About section (app version from bundle info,
  no fake legal links — only real ones if they exist, don't invent placeholder URLs).
- FR-003: If tabs beyond the visible set still need a home, they live in a custom
  in-app list screen (styled per this app's design system), not the OS default.

## Out of Scope

- Any Sentio-specific settings (subscriptions, integrations, writing personas, digest).
- Building real legal/privacy policy pages — link out only if a real URL exists
  already in this app's config; otherwise omit the row rather than fake it.
- Per-notification-kind granular toggles — one overall on/off switch for v1.

## Success Metrics

- No screen in the app ever shows iOS's default system list styling.
- An organizer can see who they're signed in as and sign out without leaving the app's
  visual design system.
