import XCTest

/// Proves the ElevenLabs voice agent actually connects, rather than that it builds.
///
/// The failure this covers was never a network problem: the Swift SDK rejects signed
/// WebSocket URLs for voice conversations, so the session died during token resolution.
/// The backend now mints a LiveKit conversation token instead. This test opens the
/// entry point and asserts the screen leaves "Connecting…" without landing on an error.
final class VoiceAgentConnectionTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testVoiceConversationConnects() throws {
        let app = XCUIApplication()

        addUIInterruptionMonitor(withDescription: "Permission prompts") { alert in
            for label in ["OK", "Allow", "Allow While Using App"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }

        app.launch()

        let agentTab = app.tabBars.buttons["Agent"]
        XCTAssertTrue(agentTab.waitForExistence(timeout: 30), "Never reached the Agent tab.")
        agentTab.tap()

        let startVoiceChat = app.buttons["Start voice chat"]
        XCTAssertTrue(startVoiceChat.waitForExistence(timeout: 20), "Voice chat entry point missing.")
        startVoiceChat.tap()

        // Give the round trip (Convex action -> ElevenLabs token -> LiveKit) time to
        // settle, tapping through the microphone prompt if it appears.
        let connecting = app.staticTexts["Connecting…"]
        _ = connecting.waitForExistence(timeout: 10)
        app.tap() // triggers the interruption monitor if a permission alert is up

        let deadline = Date().addingTimeInterval(45)
        while connecting.exists && Date() < deadline {
            _ = app.staticTexts["Connecting…"].waitForExistence(timeout: 2)
        }

        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.name = "voice-conversation-result"
        shot.lifetime = .keepAlways
        add(shot)

        XCTAssertFalse(connecting.exists, "Voice chat never got past 'Connecting…'.")
        XCTAssertEqual(app.state, .runningForeground, "App died during the voice session.")

        // The bug this covers produced an authentication failure — the SDK refusing a
        // signed WebSocket URL before any session existed. Assert specifically that
        // that class of failure is gone, rather than that no error at all appears.
        let errorTexts = app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
        XCTAssertFalse(
            errorTexts.contains("text-only") || errorTexts.lowercased().contains("authentication"),
            "Voice chat still fails at authentication: \(errorTexts)"
        )

        // Reaching the microphone stage proves the token was accepted and the LiveKit
        // session was established. The Simulator has no real audio input device, so
        // enabling the mic fails there with AVAudioEngine -4010
        // (kAudioUnitErr_CannotDoInCurrentContext). That is an environment limit, not a
        // repo bug — skip rather than pass, so this never reads as full verification.
        if errorTexts.contains("-4010") || errorTexts.contains("Audio Engine Error") {
            throw XCTSkip("""
                Connected successfully — token auth and the LiveKit session both \
                succeeded — but the Simulator cannot enable a microphone \
                (AVAudioEngine -4010). Confirming audio both ways needs a physical device.
                """)
        }

        XCTAssertFalse(
            app.staticTexts["Connection issue"].exists,
            "Voice chat reached its error state: \(errorTexts)"
        )
    }
}
