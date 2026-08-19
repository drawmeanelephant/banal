import XCTest
@testable import BANALCore

final class CodeFenceScanTests: XCTestCase {
    func testOutsideFences() {
        let text = "Hello world\nThis is standard prose."
        XCTAssertFalse(CodeFenceScan.isInsideCodeFence(in: text, at: 0))
        XCTAssertFalse(CodeFenceScan.isInsideCodeFence(in: text, at: 5))
        XCTAssertFalse(CodeFenceScan.isInsideCodeFence(in: text, at: 20))
    }

    func testInsideBacktickFences() {
        let text = """
        # Title
        ```swift
        let x = 42
        print(x)
        ```
        Footer note
        """
        let nsString = text as NSString
        let codeOffset = nsString.range(of: "let x = 42").location
        let printOffset = nsString.range(of: "print(x)").location
        let titleOffset = nsString.range(of: "# Title").location
        let footerOffset = nsString.range(of: "Footer note").location

        XCTAssertFalse(CodeFenceScan.isInsideCodeFence(in: text, at: titleOffset))
        XCTAssertTrue(CodeFenceScan.isInsideCodeFence(in: text, at: codeOffset))
        XCTAssertTrue(CodeFenceScan.isInsideCodeFence(in: text, at: printOffset))
        XCTAssertFalse(CodeFenceScan.isInsideCodeFence(in: text, at: footerOffset))
    }

    func testInsideTildeFences() {
        let text = """
        ~~~
        code block
        ~~~
        after block
        """
        let nsString = text as NSString
        let codeOffset = nsString.range(of: "code block").location
        let afterOffset = nsString.range(of: "after block").location

        XCTAssertTrue(CodeFenceScan.isInsideCodeFence(in: text, at: codeOffset))
        XCTAssertFalse(CodeFenceScan.isInsideCodeFence(in: text, at: afterOffset))
    }

    func testIndentedFences() {
        let text = """
           ```python
           def foo():
               pass
           ```
        done
        """
        let nsString = text as NSString
        let defOffset = nsString.range(of: "def foo():").location
        let doneOffset = nsString.range(of: "done").location

        XCTAssertTrue(CodeFenceScan.isInsideCodeFence(in: text, at: defOffset))
        XCTAssertFalse(CodeFenceScan.isInsideCodeFence(in: text, at: doneOffset))
    }

    func testUnclosedFence() {
        let text = """
        ```
        unclosed code
        """
        let nsString = text as NSString
        let unclosedOffset = nsString.range(of: "unclosed code").location

        XCTAssertTrue(CodeFenceScan.isInsideCodeFence(in: text, at: unclosedOffset))
    }

    func testOutOfBoundsSafety() {
        let text = "short"
        XCTAssertFalse(CodeFenceScan.isInsideCodeFence(in: text, at: -10))
        XCTAssertFalse(CodeFenceScan.isInsideCodeFence(in: text, at: 999))
    }
}
