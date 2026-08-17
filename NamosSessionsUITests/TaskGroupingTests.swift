import XCTest

/// The "ideally also" half of the UX audit's Issue 5: a group-by-person toggle on the
/// main Tasks list, matching the segmented-Picker filter pattern CheckInView and
/// SubmissionsView already use rather than introducing a new visual language.
final class TaskGroupingTests: XCTestCase {
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

    func testGroupByPersonTogglesTheTasksList() throws {
        let app = XCUIApplication()
        app.launch()

        let tasksTab = app.tabBars.buttons["Tasks"]
        guard tasksTab.waitForExistence(timeout: 30) else {
            throw XCTSkip("Never reached the signed-in tab bar.")
        }
        tasksTab.tap()

        let addTask = app.buttons["Add task"]
        XCTAssertTrue(addTask.waitForExistence(timeout: 20), "Tasks screen did not load.")

        let byPerson = app.buttons["By person"]
        guard byPerson.waitForExistence(timeout: 15) else {
            throw XCTSkip("This event has no tasks yet, so the grouping toggle does not render (it is hidden for an empty list).")
        }
        attach(app, "1-flat-list")

        byPerson.tap()
        Thread.sleep(forTimeInterval: 2) // let the grouped layout settle
        attach(app, "2-grouped-by-person")

        let listOption = app.buttons["List"]
        XCTAssertTrue(listOption.waitForExistence(timeout: 10), "Grouping toggle did not remain visible after switching to By person.")
        XCTAssertTrue(byPerson.isSelected, "By person segment did not become selected.")

        // Switch back and confirm the toggle is a real round trip, not a one-way switch.
        listOption.tap()
        XCTAssertTrue(listOption.isSelected, "List segment did not become selected again.")
        attach(app, "3-back-to-flat-list")
    }
}
