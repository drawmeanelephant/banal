import XCTest

@MainActor
final class AccessibilityAuditUITests: XCTestCase {

    private enum Config {
        static let readyTimeout: TimeInterval = 20
    }

    private struct Finding {
        let type: XCUIAccessibilityAuditType
        let text: String

        var summary: String {
            "\(type): \(text)"
        }
    }

    private struct AllowedIssue {
        let type: XCUIAccessibilityAuditType
        let descriptionContains: String

        func allows(_ finding: Finding) -> Bool {
            finding.type == type && finding.text.contains(descriptionContains)
        }
    }

    private static let allowedIssues: [AllowedIssue] = [
        AllowedIssue(
            type: .contrast,
            descriptionContains: "Contrast"
        ),
        AllowedIssue(
            type: XCUIAccessibilityAuditType(rawValue: 8),
            descriptionContains: "Element has no description"
        ),
        AllowedIssue(
            type: XCUIAccessibilityAuditType(rawValue: 4_294_967_296),
            descriptionContains: "Action is missing"
        ),
        AllowedIssue(
            type: XCUIAccessibilityAuditType(rawValue: 8_589_934_592),
            descriptionContains: "Parent/Child mismatch"
        ),
    ]

    private nonisolated(unsafe) static let log = FindingLog()

    private final class FindingLog: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [Finding] = []

        func append(_ finding: Finding) {
            lock.lock()
            items.append(finding)
            lock.unlock()
        }

        func snapshot() -> [Finding] {
            lock.lock()
            defer { lock.unlock() }
            return items
        }

        func clear() {
            lock.lock()
            items.removeAll()
            lock.unlock()
        }
    }

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func makeApp(size: String? = nil, dark: Bool) {
        app = XCUIApplication()
        app.launchEnvironment["BANAL_UI_TEST_VAULT"] = "fixture"
        if let size {
            app.launchEnvironment["BANAL_UI_TEST_WINDOW_SIZE"] = size
        }
        if dark {
            app.launchArguments += ["-AppleInterfaceStyle", "Dark"]
        }
        app.launchArguments += ["-NSDisablePersistence", "YES"]
    }

    private func shutdownApp() {
        if app.state == .runningForeground {
            app.terminate()
        }
    }

    func testMainWindowPassesAccessibilityAudit() throws {
        makeApp(dark: false)
        defer { shutdownApp() }
        app.launch()
        waitUntilReady()
        selectNote(titled: "Groceries")
        try runAudit()
    }

    func testMinimumSizeInDarkModePassesAccessibilityAuditAndKeepsListAndEditor() throws {
        makeApp(size: "720,520", dark: true)
        defer { shutdownApp() }
        app.launch()
        waitUntilReady()

        XCTAssertEqual(app.windows.firstMatch.frame.width, 720, accuracy: 4, "window is not at the 720pt minimum")
        XCTAssertLessThanOrEqual(app.windows.firstMatch.frame.height, 640, "window grew past the 520pt content minimum")
        XCTAssertGreaterThanOrEqual(app.windows.firstMatch.frame.height, 520, "window is shorter than the 520pt minimum")

        selectNote(titled: "Groceries")

        let search = anyElement(withLabel: "Search notes")
        XCTAssertTrue(search.exists, "note list search field missing at minimum size")
        XCTAssertTrue(search.isHittable, "note list search field not hittable at minimum size")

        XCTAssertTrue(app.textViews.firstMatch.exists, "editor body missing at minimum size")

        try runAudit()
    }

    func testWideWindowAndRecipeReadPassAccessibilityAudit() throws {
        makeApp(size: "1400,900", dark: false)
        defer { shutdownApp() }
        app.launch()
        waitUntilReady()

        XCTAssertEqual(app.windows.firstMatch.frame.width, 1400, accuracy: 4, "window is not at the wide size")

        selectNote(titled: "Mushroom Risotto")
        let titleField = anyElement(withLabel: "Note title")
        XCTAssertTrue(titleField.waitForExistence(timeout: 10), "selecting the recipe row did not open the editor")

        let readControl = readSwitcher()
        if let control = readControl {
            control.tap()
        } else {
            print("AX HIERARCHY DUMP (Read switcher not found):\n\(app.debugDescription)")
            XCTFail("Edit | Read switcher not shown for recipe note")
        }

        try runAudit()
    }

    private func waitUntilReady() {
        let pickerText = anyElement(withLabel: "Choose a notes folder.")
        XCTAssertFalse(
            pickerText.waitForExistence(timeout: 4),
            "the fixture vault did not resolve; the vault picker appeared instead of the window"
        )
        let search = anyElement(withLabel: "Search notes")
        guard search.waitForExistence(timeout: Config.readyTimeout) else {
            print("AX HIERARCHY DUMP (window never became ready):\n\(app.debugDescription)")
            XCTFail("main window never became ready")
            return
        }
    }

    private func anyElement(withLabel label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", label)
        ).firstMatch
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
        print("AX HIERARCHY DUMP (note row \(title) not found):\n\(app.debugDescription)")
        return false
    }

    private func readSwitcher() -> XCUIElement? {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            for type in [XCUIElement.ElementType.button, .radioButton, .checkBox] {
                let match = app.descendants(matching: type).matching(
                    NSPredicate(format: "label == 'Read' OR title == 'Read'")
                ).firstMatch
                if match.exists { return match }
            }
            usleep(250_000)
        }
        return nil
    }

    private func runAudit(function: String = #function) throws {
        Self.log.clear()
        let judge: @Sendable (XCUIAccessibilityAuditIssue) -> Bool = { issue in
            Self.log.append(Finding(
                type: issue.auditType,
                text: issue.compactDescription
            ))
            return true
        }
        try app.performAccessibilityAudit(judge)

        let findings = Self.log.snapshot()
        if !findings.isEmpty {
            print("AUDIT FINDINGS (\(function)):\n" + findings.map(\.summary).joined(separator: "\n"))
        }
        let unallowed = findings.filter { finding in
            !Self.allowedIssues.contains { $0.allows(finding) }
        }
        XCTAssertTrue(
            unallowed.isEmpty,
            "\(function) failed the accessibility audit:\n" + unallowed.map(\.summary).joined(separator: "\n")
        )
    }
}
