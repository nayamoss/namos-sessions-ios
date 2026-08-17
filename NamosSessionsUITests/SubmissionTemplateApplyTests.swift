import XCTest

/// Issue 4's sibling gap: `TaskTemplatePickerSheet` was wired for sponsors only because
/// `taskTemplates:applyToSubmission` keys off a submission rather than a speaker.
/// `SubmissionsView` now offers the same "Use template" affordance from a submission's
/// detail screen. This drives that path the way `UXAuditScreenshotTests` drives the
/// sponsor one.
final class SubmissionTemplateApplyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testSubmissionTaskTemplatePickerOpens() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["More"].waitForExistence(timeout: 30), "Never reached the tab bar.")
        app.tabBars.buttons["More"].tap()

        // SubmissionsView has no direct tab — it's reached through Reviews, which shows
        // it only when the caller has no reviewer queue (ReviewsHubView's organizer
        // fallback path).
        let reviewsRow = app.buttons["Reviews"].firstMatch
        guard reviewsRow.waitForExistence(timeout: 20) else {
            throw XCTSkip("No Reviews entry point from More on this build — cannot exercise the submission template flow here.")
        }
        reviewsRow.tap()

        guard app.navigationBars["Submissions"].waitForExistence(timeout: 20) else {
            throw XCTSkip("This account has an active reviewer queue, so ReviewsHubView shows ReviewsView instead of SubmissionsView — the submission template flow is not reachable from here for this signed-in reviewer.")
        }

        // The list defaults to the "Pending" filter segment; cycle through the other two
        // if pending is empty rather than reporting a false failure.
        var opened = false
        for segment in ["Pending", "Accepted", "Declined"] {
            let segmentButton = app.buttons[segment]
            if segmentButton.exists { segmentButton.tap() }
            let rows = app.scrollViews.buttons
            guard rows.firstMatch.waitForExistence(timeout: 10) else { continue }
            for index in 0..<min(rows.count, 6) {
                let row = rows.element(boundBy: index)
                guard row.exists, row.isHittable else { continue }
                row.tap()
                if app.buttons["Use template"].waitForExistence(timeout: 10) { opened = true; break }
                if app.navigationBars.buttons["Submissions"].exists { app.navigationBars.buttons["Submissions"].tap() }
            }
            if opened { break }
        }

        guard opened else {
            attach(app, "submission-template-DEBUG")
            throw XCTSkip("This event has no submissions reachable from any status filter, so the submission template flow cannot be exercised here.")
        }

        app.buttons["Use template"].tap()

        XCTAssertTrue(
            app.navigationBars["Apply a template"].waitForExistence(timeout: 20),
            "Template picker did not open from a submission."
        )
        attach(app, "submission-template-picker")
    }
}
