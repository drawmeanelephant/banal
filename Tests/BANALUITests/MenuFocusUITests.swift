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
        // Wait for the process to actually exit; see the note in
        // XCUIWaitHelpers about stale instances reading as crashes.
        if let app {
            xcuiWait("app exits", timeout: 8) { app.state == .notRunning }
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
            xcuiTap(publishTab, "Publish tab")
        } else {
            let altTab = app.buttons["Publish"]
            if altTab.waitForExistence(timeout: 5) {
                xcuiTap(altTab, "Publish tab")
            }
        }

        // Re-query after the tab tap: switching panes can rebuild the
        // Settings hierarchy, which leaves the old handle pointing at a
        // detached snapshot. That staleness, not a real failure, is what
        // "Settings window did not open" was reporting.
        let settings = app.descendants(matching: .any).matching(identifier: "settings-root").firstMatch
        XCTAssertTrue(
            xcuiWaitExists(settings, "Settings window", timeout: 8),
            "Settings window did not open"
        )

        // `isHittable` right after `waitForExistence` races the window's
        // open animation. Poll for the real precondition instead.
        let copyWranglerButton = settings.buttons["copy-wrangler-toml-button"]
        XCTAssertTrue(
            xcuiWaitHittable(copyWranglerButton, "Copy wrangler.toml button", timeout: 8),
            "Copy wrangler.toml button not found or clipped in Settings Publish pane"
        )

        let copyCmdButton = settings.buttons["copy-wrangler-command-button"]
        XCTAssertTrue(
            xcuiWaitHittable(copyCmdButton, "Copy command button", timeout: 8),
            "Copy command button not found or clipped in Settings Publish pane"
        )

        let deployButton = settings.buttons["deploy-to-cloudflare-button"]
        XCTAssertTrue(
            xcuiWaitHittable(deployButton, "Deploy to Cloudflare button", timeout: 8),
            "Deploy to Cloudflare button not found or clipped in Settings Publish pane"
        )
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
        XCTAssertTrue(
            xcuiWaitExists(settings, "Settings window", timeout: 10),
            "Settings window did not open"
        )
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
