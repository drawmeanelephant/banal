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

    func testInlineCodeDetection() {
        let text = "Use `swift test` for testing and `make smoke` for release."
        let nsString = text as NSString

        let beforeFirstBacktick = nsString.range(of: "Use ").location
        let insideFirstSpan = nsString.range(of: "swift test").location
        let betweenSpans = nsString.range(of: " for testing and ").location
        let insideSecondSpan = nsString.range(of: "make smoke").location
        let afterSecondSpan = nsString.range(of: " for release.").location

        XCTAssertFalse(CodeFenceScan.isInsideInlineCode(in: text, at: beforeFirstBacktick))
        XCTAssertTrue(CodeFenceScan.isInsideInlineCode(in: text, at: insideFirstSpan))
        XCTAssertFalse(CodeFenceScan.isInsideInlineCode(in: text, at: betweenSpans))
        XCTAssertTrue(CodeFenceScan.isInsideInlineCode(in: text, at: insideSecondSpan))
        XCTAssertFalse(CodeFenceScan.isInsideInlineCode(in: text, at: afterSecondSpan))
    }

    func testUnclosedInlineCodeDetection() {
        let text = "Here is unclosed `code being typed"
        let nsString = text as NSString

        let beforeBacktick = nsString.range(of: "Here is ").location
        let afterBacktick = nsString.range(of: "code being typed").location

        XCTAssertFalse(CodeFenceScan.isInsideInlineCode(in: text, at: beforeBacktick))
        XCTAssertTrue(CodeFenceScan.isInsideInlineCode(in: text, at: afterBacktick))
    }

    func testCooklangMetadataLines() {
        let text = """
        >> title: Risotto alla Milanese
        >> time: 30 minutes
           >> tags: [dinner, italian]

        Melt @butter{25%g} in a pan.
        >> notes: Serve hot
        """
        let nsString = text as NSString

        let titleOffset = nsString.range(of: "title: Risotto").location
        let timeOffset = nsString.range(of: "time: 30").location
        let tagsOffset = nsString.range(of: "tags: [dinner").location
        let stepOffset = nsString.range(of: "Melt @butter").location
        let notesOffset = nsString.range(of: "notes: Serve").location

        XCTAssertTrue(CodeFenceScan.isCooklangMetadataLine(in: text, at: titleOffset))
        XCTAssertTrue(CodeFenceScan.isCooklangMetadataLine(in: text, at: timeOffset))
        XCTAssertTrue(CodeFenceScan.isCooklangMetadataLine(in: text, at: tagsOffset))
        XCTAssertFalse(CodeFenceScan.isCooklangMetadataLine(in: text, at: stepOffset))
        XCTAssertTrue(CodeFenceScan.isCooklangMetadataLine(in: text, at: notesOffset))
    }

    func testShouldSuppressSubstitutions() {
        let text = """
        # My Document
        Here is standard prose with "quotes" and -- dashes.

        ```swift
        let flag = "--clean"
        let msg = "hello"
        ```

        Inline `var x = "--flag"` example.

        >> author: "Gordon"
        End of note.
        """
        let nsString = text as NSString

        let proseOffset = nsString.range(of: "Here is standard").location
        let fenceOffset = nsString.range(of: "let flag = \"--clean\"").location
        let inlineOffset = nsString.range(of: "var x = \"--flag\"").location
        let metadataOffset = nsString.range(of: "author: \"Gordon\"").location
        let endOffset = nsString.range(of: "End of note.").location

        XCTAssertFalse(CodeFenceScan.shouldSuppressSubstitutions(in: text, at: proseOffset))
        XCTAssertTrue(CodeFenceScan.shouldSuppressSubstitutions(in: text, at: fenceOffset))
        XCTAssertTrue(CodeFenceScan.shouldSuppressSubstitutions(in: text, at: inlineOffset))
        XCTAssertTrue(CodeFenceScan.shouldSuppressSubstitutions(in: text, at: metadataOffset))
        XCTAssertFalse(CodeFenceScan.shouldSuppressSubstitutions(in: text, at: endOffset))
    }

    func testOutOfBoundsSafety() {
        let text = "short"
        XCTAssertFalse(CodeFenceScan.isInsideCodeFence(in: text, at: -10))
        XCTAssertFalse(CodeFenceScan.isInsideCodeFence(in: text, at: 999))
        XCTAssertFalse(CodeFenceScan.isInsideInlineCode(in: text, at: -10))
        XCTAssertFalse(CodeFenceScan.isInsideInlineCode(in: text, at: 999))
        XCTAssertFalse(CodeFenceScan.isCooklangMetadataLine(in: text, at: -10))
        XCTAssertFalse(CodeFenceScan.isCooklangMetadataLine(in: text, at: 999))
        XCTAssertFalse(CodeFenceScan.shouldSuppressSubstitutions(in: text, at: -10))
        XCTAssertFalse(CodeFenceScan.shouldSuppressSubstitutions(in: text, at: 999))
    }
}

