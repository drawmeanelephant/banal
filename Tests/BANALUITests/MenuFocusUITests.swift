import XCTest

@MainActor
final class MenuFocusUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        if let app, app.state == .runningForeground {
            app.terminate()
        }
        super.tearDown()
    }

    /// #191 — File commands must act on the vault while the Settings
    /// scene is key. The Settings window exposes no focused object, so
    /// this exercises the tracked/fallback resolution path.
    func testPublishSiteStaysEnabledWhileSettingsIsKey() throws {
        app = XCUIApplication()
        app.launchEnvironment["BANAL_UI_TEST_VAULT"] = "fixture"
        app.launchArguments += ["-NSDisablePersistence", "YES"]
        app.launch()

        assertReady()
        XCTAssertTrue(fileMenuItem("Publish Site…").isEnabled, "Publish Site… disabled while the main window is key")

        openSettings()
        XCTAssertEqual(app.windows.firstMatch.title, "Publish", "Settings window did not become key")

        XCTAssertTrue(fileMenuItem("Publish Site…").isEnabled, "#191 regression: Publish Site… goes dead while Settings is key")
        XCTAssertTrue(fileMenuItem("New Note").isEnabled, "#191 regression: New Note goes dead while Settings is key")
        XCTAssertTrue(fileMenuItem("Import…").isEnabled, "#191 regression: Import… goes dead while Settings is key")
    }

    /// #191 — closing the last notes window must not strand the vault.
    /// The tracked model is held strongly so New Note still works.
    func testNewNoteSurvivesClosingLastMainWindow() throws {
        app = XCUIApplication()
        app.launchEnvironment["BANAL_UI_TEST_VAULT"] = "fixture"
        app.launchArguments += ["-NSDisablePersistence", "YES"]
        app.launch()

        assertReady()

        app.typeKey("w", modifierFlags: .command)
        usleep(500_000)

        XCTAssertTrue(fileMenuItem("New Window").isEnabled, "New Window disabled after last main window closed")
        XCTAssertTrue(fileMenuItem("New Note").isEnabled, "#191 regression: New Note disabled after last main window closed")
    }

    // MARK: - Helpers

    private func fileMenuItem(_ title: String) -> XCUIElement {
        app.menuBars.menuItems[title]
    }

    private func openSettings() {
        app.typeKey(",", modifierFlags: .command)
        usleep(800_000)
    }

    private func assertReady() {
        let pickerText = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Choose a notes folder.")
        ).firstMatch
        XCTAssertFalse(
            pickerText.waitForExistence(timeout: 4),
            "the fixture vault did not resolve; the vault picker appeared instead of the window"
        )
        let search = app.descendants(matching: .searchField).firstMatch
        guard search.waitForExistence(timeout: 20) else {
            print("AX HIERARCHY DUMP (window never became ready):\n\(app.debugDescription)")
            XCTFail("main window never became ready")
            return
        }
    }
}
