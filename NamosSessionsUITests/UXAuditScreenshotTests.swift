import XCTest

/// Drives the screens changed by the UX audit and attaches a screenshot of each.
///
/// The audit doc is explicit that a passing build is not verification and that every
/// screen it touches needs to be looked at. Host-side tap automation is unavailable on
/// this machine (osascript has no assistive access), so the walkthrough runs here.
final class UXAuditScreenshotTests: XCTestCase {
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

    func testWalkThroughAuditedScreens() throws {
        let app = XCUIApplication()
        app.launch()

        // --- Issue 1: Dashboard shows the event name and real values, not fake zeros.
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 30), "Never reached the signed-in tab bar.")
        dashboardTab.tap()

        let tasksTile = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tasks:'")).firstMatch
        XCTAssertTrue(tasksTile.waitForExistence(timeout: 20), "Tasks tile missing.")
        // Poll until the tile stops saying "loading" so the screenshot shows real data.
        let deadline = Date().addingTimeInterval(25)
        while tasksTile.label.contains("loading") && Date() < deadline {
            _ = tasksTile.waitForExistence(timeout: 1)
        }
        XCTAssertFalse(
            tasksTile.label.contains("loading"),
            "Dashboard tiles never left the loading state — data is not arriving."
        )
        attach(app, "1-dashboard")

        // --- Issue 3: New Task sheet — toolbar must not be system blue, and the sheet
        // should not be a full-height void around a two-field form.
        app.tabBars.buttons["Tasks"].tap()
        let addTask = app.buttons["Add task"]
        XCTAssertTrue(addTask.waitForExistence(timeout: 20), "Add task button missing.")
        addTask.tap()

        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 15), "New Task sheet did not open.")
        XCTAssertTrue(app.buttons["Cancel"].exists, "Cancel button missing.")
        XCTAssertTrue(app.buttons["Create"].exists, "Create button missing.")
        attach(app, "3-new-task-sheet")
        app.buttons["Cancel"].tap()

        // --- Issue 2: Agent screen composition and one clearly labelled secondary action.
        app.tabBars.buttons["Agent"].tap()
        let mic = app.descendants(matching: .any)["agent.micButton"]
        XCTAssertTrue(mic.waitForExistence(timeout: 20), "Mic button missing on Agent screen.")
        XCTAssertTrue(
            app.buttons["Start voice chat"].exists,
            "The conversational entry point is still an unlabelled icon."
        )
        attach(app, "2-agent-screen")

        // --- Issue 5: a speaker's own tasks, from the by_speaker index.
        app.tabBars.buttons["More"].tap()
        let speakersRow = app.buttons["Speakers"].firstMatch
        XCTAssertTrue(speakersRow.waitForExistence(timeout: 20), "Speakers entry missing from More.")
        speakersRow.tap()

        let speakerTasks = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Tasks for '")).firstMatch
        if !speakerTasks.waitForExistence(timeout: 25) {
            attach(app, "5-speakers-list-DEBUG")
            XCTFail("No per-speaker tasks entry point — Issue 5 is not reachable.")
            return
        }
        speakerTasks.tap()
        // The screen resolves to either real tasks or an explicit "nothing assigned"
        // state; both prove it loaded rather than hanging.
        let loaded = app.staticTexts["Outstanding"].waitForExistence(timeout: 20)
            || app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Nothing assigned to '")).firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(loaded, "Per-speaker tasks screen never resolved.")
        attach(app, "5-speaker-tasks")
    }

    /// Issue 4: the template picker is reachable and lists the event's templates.
    func testSponsorTaskTemplatePickerOpens() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["More"].waitForExistence(timeout: 30), "Never reached the tab bar.")
        app.tabBars.buttons["More"].tap()

        let sponsorsRow = app.buttons["Sponsors"].firstMatch
        XCTAssertTrue(sponsorsRow.waitForExistence(timeout: 20), "Sponsors entry missing from More.")
        sponsorsRow.tap()

        // Open the first sponsor. Skip cleanly if this event has none rather than
        // reporting a false failure.
        let rows = app.scrollViews.buttons
        guard rows.firstMatch.waitForExistence(timeout: 20) else {
            throw XCTSkip("This event has no sponsors, so the sponsor template flow cannot be exercised here.")
        }
        // firstMatch can resolve to a non-hittable swipe-action button rather than the
        // row itself, and tapping that silently does nothing.
        var opened = false
        for index in 0..<min(rows.count, 6) {
            let row = rows.element(boundBy: index)
            guard row.exists, row.isHittable else { continue }
            row.tap()
            if app.scrollViews.buttons["Tasks"].waitForExistence(timeout: 10) { opened = true; break }
            if app.navigationBars.buttons["Sponsors"].exists { app.navigationBars.buttons["Sponsors"].tap() }
        }
        guard opened else {
            attach(app, "4-sponsor-list-DEBUG")
            return XCTFail("Could not open a sponsor detail screen with a Tasks entry point.")
        }

        // Scoped to the scroll view on purpose: app.buttons["Tasks"] also matches the
        // Tasks tab-bar item, which navigates away from the sponsor entirely.
        app.scrollViews.buttons["Tasks"].firstMatch.tap()

        let useTemplate = app.buttons["Use template"]
        if !useTemplate.waitForExistence(timeout: 20) {
            attach(app, "4-sponsor-tasks-DEBUG")
            XCTFail("No 'Use template' action — Issue 4 is not reachable.")
            return
        }
        useTemplate.tap()

        XCTAssertTrue(
            app.navigationBars["Apply a template"].waitForExistence(timeout: 20),
            "Template picker did not open."
        )
        attach(app, "4-template-picker")
    }
}
