import XCTest

/// Regression coverage for the P0 mic-button crash.
///
/// The crash was an uncatchable AVFoundation NSException raised from
/// `VoiceCaptureService.startRecording()` when `installTap(onBus:)` ran with a tap
/// already installed, or with an input format reporting zero channels. A passing
/// `xcodebuild build` says nothing about either condition — the crash only appears
/// when a human actually presses the button, which is precisely the verification step
/// that kept getting skipped and then reported as done.
///
/// This test presses the button the way the fix's plan asked a human to: repeatedly,
/// and across a background/foreground cycle (which tears down and re-creates the audio
/// session, the situation that produced the stale tap in the first place).
final class MicButtonCrashTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testMicButtonSurvivesRepeatedPressesAndBackgrounding() throws {
        let app = XCUIApplication()

        // The microphone and speech-recognition prompts are system alerts owned by
        // springboard, not the app. They are pre-granted by the run script, but an
        // interruption monitor keeps the test from hanging if that ever regresses.
        addUIInterruptionMonitor(withDescription: "Permission prompts") { alert in
            for label in ["OK", "Allow", "Allow While Using App"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }

        app.launch()

        let agentTab = app.tabBars.buttons["Agent"]
        XCTAssertTrue(
            agentTab.waitForExistence(timeout: 30),
            "Agent tab never appeared — the app is not signed in or no event is selected, so the mic button was never reachable. This is a test-environment problem, not a pass."
        )
        agentTab.tap()

        let mic = app.descendants(matching: .any)["agent.micButton"]
        XCTAssertTrue(mic.waitForExistence(timeout: 15), "Mic button not found on the Agent screen.")

        // Six presses: the first installs a tap, every subsequent one re-enters
        // startRecording() and would hit the stale-tap NSException before the fix.
        for attempt in 1...6 {
            mic.press(forDuration: 0.4)
            XCTAssertEqual(
                app.state, .runningForeground,
                "App died after mic press #\(attempt) — the crash is NOT fixed."
            )
        }

        // Backgrounding deactivates the audio session out from under the engine; the
        // press after returning is the case that originally produced the crash report.
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10), "App did not background.")
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "App did not return to foreground.")

        XCTAssertTrue(mic.waitForExistence(timeout: 15), "Mic button missing after foregrounding.")
        for attempt in 1...3 {
            mic.press(forDuration: 0.4)
            XCTAssertEqual(
                app.state, .runningForeground,
                "App died after post-foreground mic press #\(attempt) — the crash is NOT fixed."
            )
        }
    }
}
