import XCTest

/// #225 — ⌘⌫ must trash the selected note whether focus is in the editor
/// or the note list. The list path goes through the menu bar; the editor
/// path additionally needs `EditorTextView.performKeyEquivalent` because
/// AppKit offers key equivalents to the view tree first and `NSTextView`
/// claims ⌘⌫ for `deleteToBeginningOfParagraph:`.
@MainActor
final class TrashShortcutUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchWithFixture() {
        app = XCUIApplication()
        app.launchEnvironment["BANAL_UI_TEST_VAULT"] = "fixture"
        app.launchArguments += ["-NSDisablePersistence", "YES"]
        app.launch()
        assertReady()
    }

    private func shutdownApp() {
        if let app, app.state == .runningForeground {
            app.terminate()
        }
    }

    func testCommandBackspaceTrashesNoteWhileEditorFocused() throws {
        launchWithFixture()
        defer { shutdownApp() }

        XCTAssertTrue(selectNote(titled: "Groceries"), "fixture note Groceries not found")

        // Focus the editor body, then ⌘⌫. Before #225 this was a silent
        // no-op: NSTextView ate the key equivalent before the menu saw it.
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "editor body missing")
        editor.click()

        app.typeKey(XCUIKeyboardKey.delete, modifierFlags: .command)

        XCTAssertTrue(
            waitUntilGone(rowTitled: "Groceries"),
            "⌘⌫ with the editor focused did not trash the note (#225 regression)"
        )
    }

    func testCommandBackspaceTrashesNoteWhileListFocused() throws {
        launchWithFixture()
        defer { shutdownApp() }

        XCTAssertTrue(selectNote(titled: "A page"), "fixture note A page not found")

        // Clicking the row leaves the list as first responder — the menu-bar
        // path the issue reports as already working. Keep it covered so the
        // two focus states can never drift apart.
        app.typeKey(XCUIKeyboardKey.delete, modifierFlags: .command)

        XCTAssertTrue(
            waitUntilGone(rowTitled: "A page"),
            "⌘⌫ with the list focused did not trash the note"
        )
    }

    // MARK: - Helpers

    private func row(titled title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@", title)
        ).firstMatch
    }

    private func waitUntilGone(rowTitled title: String, timeout: TimeInterval = 10) -> Bool {
        let row = row(titled: title)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !row.exists { return true }
            usleep(200_000)
        }
        return !row.exists
    }

    @discardableResult
    private func selectNote(titled title: String) -> Bool {
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            for type in [XCUIElement.ElementType.tableRow, .outlineRow, .cell] {
                let match = app.descendants(matching: type).matching(
                    NSPredicate(format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", title, title)
                ).firstMatch
                if match.exists {
                    match.tap()
                    return true
                }
            }
            let text = app.staticTexts.matching(
                NSPredicate(format: "value CONTAINS[c] %@ OR label CONTAINS[c] %@", title, title)
            ).firstMatch
            if text.exists {
                text.tap()
                return true
            }
            usleep(300_000)
        }
        return false
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
