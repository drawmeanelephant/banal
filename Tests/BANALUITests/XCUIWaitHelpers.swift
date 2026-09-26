import XCTest

/// Shared wait helpers for the XCUITest suite.
///
/// These exist to kill a specific, repeated flake: asserting an
/// `isHittable` flag the instant after `waitForExistence` returns. That is
/// a time-of-check/time-of-use race — the element is in the tree, but the
/// window is still animating open or the scroll view is still settling, so
/// the hittable answer is momentarily `false`. Polling turns a race into a
/// deterministic wait, and costs nothing when the thing is already there.
///
/// The second, subtler flake is *stale references*. Interacting with a
/// SwiftUI control (tapping a Settings tab, for example) can rebuild the
/// hierarchy, leaving a previously-queried `XCUIElement` pointing at a
/// detached snapshot. Re-query through these helpers after any interaction
/// rather than reusing the old handle.
enum XCUITimeout {
    /// Long enough to ride out a window animation on a loaded CI box,
    /// short enough that a genuine failure still reports promptly.
    static let element: TimeInterval = 10
    static let hittable: TimeInterval = 10
}

/// Poll `condition` until it holds or the timeout expires, pumping the
/// run loop so XCTest's own machinery keeps running.
@discardableResult
func xcuiWait(
    _ description: String,
    timeout: TimeInterval = XCUITimeout.element,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () -> Bool
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if condition() { return true }
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
    } while Date() < deadline
    return condition()
}

/// Wait for an element to exist (not merely to be queried).
func xcuiWaitExists(
    _ element: XCUIElement,
    _ description: String = "",
    timeout: TimeInterval = XCUITimeout.element,
    file: StaticString = #filePath,
    line: UInt = #line
) -> Bool {
    xcuiWait(
        "\(description.isEmpty ? "element" : description) exists",
        timeout: timeout, file: file, line: line
    ) { element.exists }
}

/// Wait for an element to exist *and* be hittable, which is the real
/// precondition for "the user can press this".
func xcuiWaitHittable(
    _ element: XCUIElement,
    _ description: String = "",
    timeout: TimeInterval = XCUITimeout.hittable,
    file: StaticString = #filePath,
    line: UInt = #line
) -> Bool {
    xcuiWait(
        "\(description.isEmpty ? "element" : description) is hittable",
        timeout: timeout, file: file, line: line
    ) { element.exists && element.isHittable }
}

/// Tap an element once it is genuinely hittable. Prefer this over a bare
/// `.click()` when the element sits inside a scroll view, where hit-point
/// resolution intermittently fails with
/// "Unable to find hit point for ...".
func xcuiTap(
    _ element: XCUIElement,
    _ description: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let ok = xcuiWaitHittable(element, description, file: file, line: line)
    if ok {
        element.tap()
    } else {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}

extension XCUIApplication {
    /// Terminate and relaunch, so each test starts from a known process
    /// state. A leftover instance from a previous test shows up as
    /// "Critical process BANAL crashed", which is really a stale-process
    /// artifact rather than a crash in the code under test.
    func relaunchForUITest(
        vault fixture: String = "fixture",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if state != .notRunning { terminate() }
        // Give the previous instance time to fully exit before relaunching.
        xcuiWait("previous instance exits", timeout: 5, file: file, line: line) {
            self.state == .notRunning
        }
        launchEnvironment["BANAL_UI_TEST_VAULT"] = fixture
        launchArguments += ["-NSDisablePersistence", "YES"]
        launch()
    }
}
