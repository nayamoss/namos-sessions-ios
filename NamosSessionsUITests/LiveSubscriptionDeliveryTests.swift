import XCTest

/// Proves `tasks:list` delivers over the live Convex WebSocket subscription, not just
/// the initial HTTP seed.
///
/// `TasksViewModel.startSubscription()` seeds once via HTTP (`refresh()`), then hands
/// the screen over entirely to `ConvexLiveClient`'s subscription — nothing else ever
/// reassigns `tasks`. `CreateTaskSheet` calls `viewModel.createTask(...)` and dismisses;
/// it does NOT call `refresh()`. So if a task created through the app's own "Add task"
/// flow shows up in the list afterward, the only path that could have put it there is
/// the live subscription re-firing after the mutation committed — not the HTTP seed,
/// which already ran once before the write happened.
final class LiveSubscriptionDeliveryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCreatedTaskArrivesOverLiveSubscriptionWithoutRefresh() throws {
        let app = XCUIApplication()
        app.launch()

        // Reach the signed-in tab bar; a missing Tasks tab means no event/session is
        // configured in this environment, which is a setup problem, not a subscription bug.
        let tasksTab = app.tabBars.buttons["Tasks"]
        guard tasksTab.waitForExistence(timeout: 30) else {
            throw XCTSkip("Never reached the signed-in tab bar — no authenticated session/event available to exercise the subscription.")
        }
        tasksTab.tap()

        // Let the initial HTTP seed settle before the write, so any appearance of the
        // new row afterward cannot be attributed to that first load.
        let addTask = app.buttons["Add task"]
        XCTAssertTrue(addTask.waitForExistence(timeout: 20), "Add task entry point missing — cannot perform the separate write this test needs.")
        // A brief settle window for the initial `refresh()` HTTP call queued by
        // `startSubscription()` to complete before we write anything new.
        Thread.sleep(forTimeInterval: 3)

        let marker = "Live sub check \(Int(Date().timeIntervalSince1970))"

        addTask.tap()
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 15), "New Task sheet did not open.")

        let titleField = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 10), "Task title input missing.")
        titleField.tap()
        titleField.typeText(marker)

        let createButton = app.buttons["Create"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 10), "Create button missing.")
        XCTAssertTrue(createButton.isEnabled, "Create button never enabled after typing a title.")
        createButton.tap()

        // The sheet dismissing is not itself proof of anything — `createTask()` returns
        // true and dismisses purely on a successful HTTP mutation response, before any
        // subscription round trip. The real assertion is below.
        XCTAssertTrue(app.navigationBars["New Task"].waitForNonExistence(timeout: 15), "New Task sheet never dismissed after Create.")

        // Nothing in this app calls refresh() again after creating a task. The only
        // remaining path for the new row to reach `viewModel.tasks` is the live
        // subscription re-firing once the mutation committed server-side.
        //
        // `LazyVStack` only instantiates rows near the visible viewport, and new tasks
        // are appended at the end of the list (creation order), so the row genuinely
        // will not exist in the accessibility tree until scrolled into view — that is
        // a rendering fact, not evidence the subscription failed to deliver.
        let newRow = app.staticTexts[marker]
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<20 {
            if newRow.exists { break }
            scroll.swipeUp(velocity: .fast)
        }
        let delivered = newRow.waitForExistence(timeout: 20)

        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.name = "live-subscription-delivery-result"
        shot.lifetime = .keepAlways
        add(shot)

        XCTAssertTrue(
            delivered,
            "'\(marker)' never appeared in the Tasks list. Either the mutation failed, or the live Convex subscription is not delivering updates — only the initial HTTP seed is."
        )
    }
}
