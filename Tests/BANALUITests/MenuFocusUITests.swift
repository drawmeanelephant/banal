import XCTest

@MainActor
final class MenuFocusUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func shutdownApp() {
        if let app, app.state == .runningForeground {
            app.terminate()
        }
    }

    /// #191 — File commands must act on the vault while the Settings
    /// scene is key. The Settings window exposes no focused object, so
    /// this exercises the tracked/fallback resolution path.
    func testPublishSiteStaysEnabledWhileSettingsIsKey() throws {
        app = XCUIApplication()
        app.launchEnvironment["BANAL_UI_TEST_VAULT"] = "fixture"
        app.launchArguments += ["-NSDisablePersistence", "YES"]
        app.launch()
        defer { shutdownApp() }

        assertReady()
        XCTAssertTrue(fileMenuItem("Publish Site…").isEnabled, "Publish Site… disabled while the main window is key")

        openSettings()

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
        defer { shutdownApp() }

        assertReady()

        app.typeKey("w", modifierFlags: .command)
        usleep(500_000)

        XCTAssertTrue(fileMenuItem("New Window").isEnabled, "New Window disabled after last main window closed")
        XCTAssertTrue(fileMenuItem("New Note").isEnabled, "#191 regression: New Note disabled after last main window closed")
    }

    /// #215 — Publish pane in Settings window must fit all controls
    /// and action buttons without clipping the Deploy section.
    func testPublishSettingsPaneFitsAllControlsWithoutClipping() throws {
        app = XCUIApplication()
        app.launchEnvironment["BANAL_UI_TEST_VAULT"] = "fixture"
        app.launchArguments += ["-NSDisablePersistence", "YES"]
        app.launch()
        defer { shutdownApp() }

        assertReady()
        openSettings()

        let publishTab = app.toolbars.buttons["Publish"]
        if publishTab.waitForExistence(timeout: 5) {
            publishTab.tap()
        } else {
            let altTab = app.buttons["Publish"]
            if altTab.waitForExistence(timeout: 5) {
                altTab.tap()
            }
        }

        let settings = app.descendants(matching: .any).matching(identifier: "settings-root").firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 8), "Settings window did not open")

        let copyWranglerButton = settings.buttons["copy-wrangler-toml-button"]
        XCTAssertTrue(copyWranglerButton.waitForExistence(timeout: 5), "Copy wrangler.toml button not found in Settings Publish pane")
        XCTAssertTrue(copyWranglerButton.isHittable, "Copy wrangler.toml button is clipped in Settings window")

        let copyCmdButton = settings.buttons["copy-wrangler-command-button"]
        XCTAssertTrue(copyCmdButton.waitForExistence(timeout: 5), "Copy command button not found in Settings Publish pane")
        XCTAssertTrue(copyCmdButton.isHittable, "Copy command button is clipped in Settings window")

        let deployButton = settings.buttons["deploy-to-cloudflare-button"]
        XCTAssertTrue(deployButton.waitForExistence(timeout: 5), "Deploy to Cloudflare button not found in Settings Publish pane")
        XCTAssertTrue(deployButton.isHittable, "Deploy to Cloudflare button is clipped in Settings window")
    }

    // MARK: - Helpers

    private func fileMenuItem(_ title: String) -> XCUIElement {
        app.menuBars.menuItems[title]
    }

    /// ⌘, opens Settings and this waits until it is actually up. Which
    /// pane the window shows is machine state — SwiftUI persists the
    /// last-selected tab (`com_apple_SwiftUI_Settings_selectedTabIndex`)
    /// and `-NSDisablePersistence` does not clear it — so tests must
    /// never assert on the pane title.
    private func openSettings() {
        app.typeKey(",", modifierFlags: .command)
        let settings = app.descendants(matching: .any).matching(
            identifier: "settings-root"
        ).firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 8), "Settings window did not open")
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
