# Settings screen + tab overflow fix — Implementation Plan

**Do not start until** the ElevenLabs voice agent build (docs/features/elevenlabs-voice-agent/)
is verified complete and reported — both touch `ContentView.swift`/`AgentChatView.swift`
heavily, same collision class that's already happened twice. Sequence, don't parallelize.

## Phase 1: Tab restructure (bug fix)

- [x] T001: Read `ContentView.swift` fresh (it will have changed after the ElevenLabs
      work lands) — confirm the current full tab list before touching anything.
- [x] T002: Reduce to 5 or fewer visible `TabView` tabs. Recommended split: Dashboard,
      Agent, Tasks, Agenda, and a "More" tab — but this is a judgment call for whoever
      builds it based on what actually ships by then; the hard requirement is zero
      reliance on iOS's default overflow list, not this exact split.
- [x] T003: Build a custom `MoreView` (styled with `NamosColor`, matching every other
      screen's card/list conventions — no borders/shadows, off-white surfaces) that
      lists whatever tabs didn't fit, replacing the system default entirely.

## Phase 2: Settings screen (feature)

- [x] T004: Build `SettingsView.swift` per requirements.md's FR-002 — Account (email +
      current event + sign-out w/ confirmation dialog, using `ClerkAuthManager` exactly
      as it exists today), Appearance (color scheme picker, `AppStorage`), Notifications
      (single on/off toggle), About (bundle version string only).
- [x] T005: Add Settings as an entry point — either its own tab slot or a row inside
      the custom `MoreView` from T003, implementer's call based on final tab count.

## Phase 3: Verification (REQUIRED)

- [x] T006: `xcodegen generate` + `xcodebuild build` succeeds.
- [~] T007: Install + launch in Simulator, screenshot the tab bar AND the More/Settings
      screens specifically — visually confirm zero system-default list styling anywhere
      (this is the whole point of the fix, don't skip visually checking it). Tab bar
      confirmed visually via screenshot (5 tabs, NamosColor accent, no system blue/no
      OS overflow list). More/Settings screens were NOT visually confirmed by tap —
      UI tap automation blocked (no Accessibility permission for System Events/cliclick,
      consistent with every prior run on this app) — verified instead by direct source
      read of MoreView.swift/SettingsView.swift (NamosColor tokens throughout, zero
      borders/shadows/system-blue found via grep).
- [ ] T008: Confirm sign-out actually works (returns to the sign-in screen) — NOT verified,
      blocked by the same tap-automation limitation as T007 (requires navigating to
      Settings and tapping Sign Out). Code path was reviewed: SettingsView calls
      `await auth.signOut()` inside a confirmationDialog, and ContentView's existing
      `if auth.isSignedIn { ... } else { SignInModal() }` branch (unchanged) already
      handles the transition — this is inference from code, not an observed run.

## Verification Checklist

- [x] Tab bar shows 5 or fewer tabs, no OS-default "More" list anywhere. (screenshot-verified)
- [x] Settings screen matches `NamosColor` design tokens exactly like every other screen. (source-verified, not screenshot-verified)
- [ ] Sign-out works and is confirmed before executing (not a bare single tap). (source-verified only, not run)
- [x] Existing tabs/features all still reachable — nothing silently dropped in the
      restructure. (source-verified: all 5 dropped tabs routed via MoreDestination/navigationDestination)
