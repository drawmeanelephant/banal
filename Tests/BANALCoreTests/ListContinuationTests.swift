import XCTest
@testable import BANALCore

final class ListContinuationTests: XCTestCase {
    // MARK: - Bullet Lists

    func testBulletListContinuation() {
        let text = "- First item"
        let range = NSRange(location: (text as NSString).length, length: 0)
        let action = ListContinuation.action(in: text, selectedRange: range)

        XCTAssertNotNil(action)
        XCTAssertEqual(action?.kind, .continuation)
        XCTAssertEqual(action?.range, range)
        XCTAssertEqual(action?.text, "\n- ")
        XCTAssertEqual(action?.newCaretPosition, (text as NSString).length + 3)
    }

    func testAsteriskAndPlusBulletContinuation() {
        let starText = "* Star item"
        let starRange = NSRange(location: (starText as NSString).length, length: 0)
        let starAction = ListContinuation.action(in: starText, selectedRange: starRange)
        XCTAssertEqual(starAction?.kind, .continuation)
        XCTAssertEqual(starAction?.text, "\n* ")

        let plusText = "+ Plus item"
        let plusRange = NSRange(location: (plusText as NSString).length, length: 0)
        let plusAction = ListContinuation.action(in: plusText, selectedRange: plusRange)
        XCTAssertEqual(plusAction?.kind, .continuation)
        XCTAssertEqual(plusAction?.text, "\n+ ")
    }

    func testEmptyBulletBreakout() {
        let text = "- "
        let range = NSRange(location: 2, length: 0)
        let action = ListContinuation.action(in: text, selectedRange: range)

        XCTAssertNotNil(action)
        XCTAssertEqual(action?.kind, .breakout)
        XCTAssertEqual(action?.range, NSRange(location: 0, length: 2))
        XCTAssertEqual(action?.text, "")
        XCTAssertEqual(action?.newCaretPosition, 0)
    }

    func testEmptyAsteriskAndPlusBreakout() {
        let starText = "* "
        let starAction = ListContinuation.action(in: starText, selectedRange: NSRange(location: 2, length: 0))
        XCTAssertEqual(starAction?.kind, .breakout)
        XCTAssertEqual(starAction?.range, NSRange(location: 0, length: 2))
        XCTAssertEqual(starAction?.text, "")
        XCTAssertEqual(starAction?.newCaretPosition, 0)

        let plusText = "+ "
        let plusAction = ListContinuation.action(in: plusText, selectedRange: NSRange(location: 2, length: 0))
        XCTAssertEqual(plusAction?.kind, .breakout)
        XCTAssertEqual(plusAction?.range, NSRange(location: 0, length: 2))
        XCTAssertEqual(plusAction?.text, "")
        XCTAssertEqual(plusAction?.newCaretPosition, 0)
    }

    // MARK: - Numbered Lists

    func testNumberedListContinuation() {
        let text = "1. First"
        let range = NSRange(location: (text as NSString).length, length: 0)
        let action = ListContinuation.action(in: text, selectedRange: range)

        XCTAssertNotNil(action)
        XCTAssertEqual(action?.kind, .continuation)
        XCTAssertEqual(action?.text, "\n2. ")
        XCTAssertEqual(action?.newCaretPosition, (text as NSString).length + 4)
    }

    func testNumberedListMultiDigitIncrement() {
        let text = "9. Ninth item"
        let range = NSRange(location: (text as NSString).length, length: 0)
        let action = ListContinuation.action(in: text, selectedRange: range)

        XCTAssertNotNil(action)
        XCTAssertEqual(action?.kind, .continuation)
        XCTAssertEqual(action?.text, "\n10. ")
    }

    func testParenthesisNumberedListContinuation() {
        let text = "1) First"
        let range = NSRange(location: (text as NSString).length, length: 0)
        let action = ListContinuation.action(in: text, selectedRange: range)

        XCTAssertNotNil(action)
        XCTAssertEqual(action?.kind, .continuation)
        XCTAssertEqual(action?.text, "\n2) ")
    }

    func testEmptyNumberedListBreakout() {
        let text = "2. "
        let range = NSRange(location: 3, length: 0)
        let action = ListContinuation.action(in: text, selectedRange: range)

        XCTAssertNotNil(action)
        XCTAssertEqual(action?.kind, .breakout)
        XCTAssertEqual(action?.range, NSRange(location: 0, length: 3))
        XCTAssertEqual(action?.text, "")
        XCTAssertEqual(action?.newCaretPosition, 0)
    }

    // MARK: - Checkbox Lists

    func testCheckboxListContinuation() {
        let text = "- [ ] Todo item"
        let range = NSRange(location: (text as NSString).length, length: 0)
        let action = ListContinuation.action(in: text, selectedRange: range)

        XCTAssertNotNil(action)
        XCTAssertEqual(action?.kind, .continuation)
        XCTAssertEqual(action?.text, "\n- [ ] ")
    }

    func testCheckedCheckboxContinuesAsUnchecked() {
        let textLower = "- [x] Done item"
        let rangeLower = NSRange(location: (textLower as NSString).length, length: 0)
        let actionLower = ListContinuation.action(in: textLower, selectedRange: rangeLower)
        XCTAssertEqual(actionLower?.kind, .continuation)
        XCTAssertEqual(actionLower?.text, "\n- [ ] ")

        let textUpper = "- [X] Done item"
        let rangeUpper = NSRange(location: (textUpper as NSString).length, length: 0)
        let actionUpper = ListContinuation.action(in: textUpper, selectedRange: rangeUpper)
        XCTAssertEqual(actionUpper?.kind, .continuation)
        XCTAssertEqual(actionUpper?.text, "\n- [ ] ")
    }

    func testEmptyCheckboxBreakout() {
        let text = "- [ ] "
        let range = NSRange(location: 6, length: 0)
        let action = ListContinuation.action(in: text, selectedRange: range)

        XCTAssertNotNil(action)
        XCTAssertEqual(action?.kind, .breakout)
        XCTAssertEqual(action?.range, NSRange(location: 0, length: 6))
        XCTAssertEqual(action?.text, "")
        XCTAssertEqual(action?.newCaretPosition, 0)

        // Also bare "- [ ]" without trailing space
        let bareText = "- [ ]"
        let bareAction = ListContinuation.action(in: bareText, selectedRange: NSRange(location: 5, length: 0))
        XCTAssertEqual(bareAction?.kind, .breakout)
        XCTAssertEqual(bareAction?.range, NSRange(location: 0, length: 5))
        XCTAssertEqual(bareAction?.text, "")
    }

    // MARK: - Indentation

    func testIndentedListContinuation() {
        let text = "  - Indented item"
        let range = NSRange(location: (text as NSString).length, length: 0)
        let action = ListContinuation.action(in: text, selectedRange: range)

        XCTAssertNotNil(action)
        XCTAssertEqual(action?.kind, .continuation)
        XCTAssertEqual(action?.text, "\n  - ")
    }

    func testIndentedNumberedContinuation() {
        let text = "    1. Deeply indented"
        let range = NSRange(location: (text as NSString).length, length: 0)
        let action = ListContinuation.action(in: text, selectedRange: range)

        XCTAssertNotNil(action)
        XCTAssertEqual(action?.kind, .continuation)
        XCTAssertEqual(action?.text, "\n    2. ")
    }

    func testIndentedEmptyBreakout() {
        let text = "  - "
        let range = NSRange(location: 4, length: 0)
        let action = ListContinuation.action(in: text, selectedRange: range)

        XCTAssertNotNil(action)
        XCTAssertEqual(action?.kind, .breakout)
        XCTAssertEqual(action?.range, NSRange(location: 0, length: 4))
        XCTAssertEqual(action?.text, "")
        XCTAssertEqual(action?.newCaretPosition, 0)
    }

    // MARK: - Code Fences

    func testCodeFenceSuppression() {
        let text = """
        ```
        - code bullet
        ```
        """
        let nsString = text as NSString
        let offset = nsString.range(of: "- code bullet").location + 13
        let action = ListContinuation.action(in: text, selectedRange: NSRange(location: offset, length: 0))

        XCTAssertNil(action, "Should not auto-continue list inside backtick fence")

        let tildeText = """
        ~~~
        1. code numbered
        ~~~
        """
        let tildeNSString = tildeText as NSString
        let tildeOffset = tildeNSString.range(of: "1. code numbered").location + 16
        let tildeAction = ListContinuation.action(in: tildeText, selectedRange: NSRange(location: tildeOffset, length: 0))

        XCTAssertNil(tildeAction, "Should not auto-continue list inside tilde fence")
    }

    // MARK: - Caret Positioning & Splitting

    func testCaretAtStartOfListLineReturnsNil() {
        let text = "- First item"
        let action = ListContinuation.action(in: text, selectedRange: NSRange(location: 0, length: 0))
        XCTAssertNil(action, "Pressing Return at column 0 should insert plain newline above")
    }

    func testCaretInsideMarkerReturnsNil() {
        let text = "- First item"
        let action = ListContinuation.action(in: text, selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNil(action, "Pressing Return between bullet and space should not continue list")
    }

    func testCaretInMiddleOfItemSplitsLine() {
        let text = "- First and second"
        // Cursor between "First " and "and"
        let offset = 8
        let action = ListContinuation.action(in: text, selectedRange: NSRange(location: offset, length: 0))

        XCTAssertNotNil(action)
        XCTAssertEqual(action?.kind, .continuation)
        XCTAssertEqual(action?.range, NSRange(location: offset, length: 0))
        XCTAssertEqual(action?.text, "\n- ")
        XCTAssertEqual(action?.newCaretPosition, offset + 3)
    }

    // MARK: - Multi-line Document Flow

    func testMultiLineGateSequence() {
        // Gate from Card E-3:
        // 1. Type "- First item", hit Return
        var text = "- First item"
        var cursor = (text as NSString).length
        let action1 = ListContinuation.action(in: text, selectedRange: NSRange(location: cursor, length: 0))
        XCTAssertNotNil(action1)
        XCTAssertEqual(action1?.kind, .continuation)

        // Apply action 1
        text = (text as NSString).replacingCharacters(in: action1!.range, with: action1!.text)
        cursor = action1!.newCaretPosition
        XCTAssertEqual(text, "- First item\n- ")
        XCTAssertEqual(cursor, 15)

        // 2. Hit Return again immediately on "- "
        let action2 = ListContinuation.action(in: text, selectedRange: NSRange(location: cursor, length: 0))
        XCTAssertNotNil(action2)
        XCTAssertEqual(action2?.kind, .breakout)

        // Apply action 2
        text = (text as NSString).replacingCharacters(in: action2!.range, with: action2!.text)
        cursor = action2!.newCaretPosition
        XCTAssertEqual(text, "- First item\n")
        XCTAssertEqual(cursor, 13)
    }

    func testBreakoutBetweenLines() {
        let text = "- First\n- \n- Third"
        let nsString = text as NSString
        let emptyBulletLineStart = nsString.range(of: "- \n").location
        let cursor = emptyBulletLineStart + 2 // end of "- "

        let action = ListContinuation.action(in: text, selectedRange: NSRange(location: cursor, length: 0))
        XCTAssertNotNil(action)
        XCTAssertEqual(action?.kind, .breakout)
        XCTAssertEqual(action?.range, NSRange(location: emptyBulletLineStart, length: 2))

        let result = nsString.replacingCharacters(in: action!.range, with: action!.text)
        XCTAssertEqual(result, "- First\n\n- Third")
    }

    // MARK: - Non-list Edge Cases

    func testNonListLines() {
        let headings = "# Heading"
        XCTAssertNil(ListContinuation.action(in: headings, selectedRange: NSRange(location: 9, length: 0)))

        let horizontalRule = "---"
        XCTAssertNil(ListContinuation.action(in: horizontalRule, selectedRange: NSRange(location: 3, length: 0)))

        let decimalNumber = "3.14159 is pi"
        XCTAssertNil(ListContinuation.action(in: decimalNumber, selectedRange: NSRange(location: 13, length: 0)))

        let attachedHyphen = "-attached"
        XCTAssertNil(ListContinuation.action(in: attachedHyphen, selectedRange: NSRange(location: 9, length: 0)))

        let plainProse = "Just regular text."
        XCTAssertNil(ListContinuation.action(in: plainProse, selectedRange: NSRange(location: 18, length: 0)))
    }

    func testSelectionLengthGreaterThanZeroReturnsNil() {
        let text = "- Selected item"
        let action = ListContinuation.action(in: text, selectedRange: NSRange(location: 2, length: 8))
        XCTAssertNil(action, "Selecting text and pressing Return should perform standard replacement")
    }
}
