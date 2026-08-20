import XCTest
@testable import BANALCore

final class CheckboxToggleTests: XCTestCase {
    // MARK: - Unchecked to Checked

    func testUncheckedCheckboxTogglesToChecked() {
        let text = "- [ ] buy lemons"
        let nsString = text as NSString

        // Click on bracket `[`
        let actionBracket = CheckboxToggle.toggleAction(in: text, at: 2)
        XCTAssertNotNil(actionBracket)
        XCTAssertFalse(actionBracket!.isChecked)
        XCTAssertEqual(actionBracket!.toggledCharacter, "x")
        XCTAssertEqual(actionBracket!.replacementRange, NSRange(location: 3, length: 1))
        XCTAssertEqual(actionBracket!.replacementText, "x")

        let replaced = nsString.replacingCharacters(in: actionBracket!.replacementRange, with: actionBracket!.replacementText)
        XCTAssertEqual(replaced, "- [x] buy lemons")

        // Click on bullet `-`
        let actionBullet = CheckboxToggle.toggleAction(in: text, at: 0)
        XCTAssertNotNil(actionBullet)
        XCTAssertEqual(actionBullet!.toggledCharacter, "x")

        // Click on inner space ` `
        let actionInner = CheckboxToggle.toggleAction(in: text, at: 3)
        XCTAssertNotNil(actionInner)
        XCTAssertEqual(actionInner!.toggledCharacter, "x")

        // Click on closing bracket `]`
        let actionClose = CheckboxToggle.toggleAction(in: text, at: 4)
        XCTAssertNotNil(actionClose)
        XCTAssertEqual(actionClose!.toggledCharacter, "x")
    }

    // MARK: - Checked to Unchecked

    func testCheckedCheckboxTogglesToUnchecked() {
        let text = "- [x] buy lemons"
        let nsString = text as NSString

        let action = CheckboxToggle.toggleAction(in: text, at: 3)
        XCTAssertNotNil(action)
        XCTAssertTrue(action!.isChecked)
        XCTAssertEqual(action!.toggledCharacter, " ")
        XCTAssertEqual(action!.replacementRange, NSRange(location: 3, length: 1))
        XCTAssertEqual(action!.replacementText, " ")

        let replaced = nsString.replacingCharacters(in: action!.replacementRange, with: action!.replacementText)
        XCTAssertEqual(replaced, "- [ ] buy lemons")
    }

    func testUppercaseCheckedCheckboxTogglesToUnchecked() {
        let text = "- [X] finished task"
        let nsString = text as NSString

        let action = CheckboxToggle.toggleAction(in: text, at: 2)
        XCTAssertNotNil(action)
        XCTAssertTrue(action!.isChecked)
        XCTAssertEqual(action!.toggledCharacter, " ")

        let replaced = nsString.replacingCharacters(in: action!.replacementRange, with: action!.replacementText)
        XCTAssertEqual(replaced, "- [ ] finished task")
    }

    // MARK: - Bullet Variants (* and +)

    func testAsteriskAndPlusCheckboxVariants() {
        let starText = "* [ ] star item"
        let starAction = CheckboxToggle.toggleAction(in: starText, at: 2)
        XCTAssertNotNil(starAction)
        XCTAssertEqual(starAction!.toggledCharacter, "x")

        let plusText = "+ [x] plus item"
        let plusAction = CheckboxToggle.toggleAction(in: plusText, at: 2)
        XCTAssertNotNil(plusAction)
        XCTAssertEqual(plusAction!.toggledCharacter, " ")
    }

    // MARK: - Indented Checkboxes

    func testIndentedCheckbox() {
        let text = "    - [ ] nested todo"
        let nsString = text as NSString

        // Clicking in indentation spaces should not toggle
        XCTAssertNil(CheckboxToggle.toggleAction(in: text, at: 0))
        XCTAssertNil(CheckboxToggle.toggleAction(in: text, at: 2))

        // Clicking on `- [ ]` prefix
        let action = CheckboxToggle.toggleAction(in: text, at: 7) // on inner space
        XCTAssertNotNil(action)
        XCTAssertEqual(action!.bracketRange, NSRange(location: 6, length: 3))
        XCTAssertEqual(action!.innerRange, NSRange(location: 7, length: 1))
        XCTAssertEqual(action!.toggledCharacter, "x")

        let replaced = nsString.replacingCharacters(in: action!.replacementRange, with: action!.replacementText)
        XCTAssertEqual(replaced, "    - [x] nested todo")
    }

    // MARK: - Multi-line Document

    func testMultiLineDocumentTargeting() {
        let text = """
        # Tasks

        - [ ] First item
        - [x] Second item
        - Plain bullet
        - [ ] Third item
        """
        let nsString = text as NSString

        // Click line 1 (First item)
        let firstPos = nsString.range(of: "- [ ] First item").location + 2
        let firstAction = CheckboxToggle.toggleAction(in: text, at: firstPos)
        XCTAssertNotNil(firstAction)
        XCTAssertFalse(firstAction!.isChecked)
        XCTAssertEqual(firstAction!.toggledCharacter, "x")

        // Click line 2 (Second item)
        let secondPos = nsString.range(of: "- [x] Second item").location + 2
        let secondAction = CheckboxToggle.toggleAction(in: text, at: secondPos)
        XCTAssertNotNil(secondAction)
        XCTAssertTrue(secondAction!.isChecked)
        XCTAssertEqual(secondAction!.toggledCharacter, " ")

        // Click line 3 (Plain bullet)
        let plainPos = nsString.range(of: "- Plain bullet").location
        XCTAssertNil(CheckboxToggle.toggleAction(in: text, at: plainPos))

        // Click line 4 (Third item)
        let thirdPos = nsString.range(of: "- [ ] Third item").location + 3
        let thirdAction = CheckboxToggle.toggleAction(in: text, at: thirdPos)
        XCTAssertNotNil(thirdAction)
        XCTAssertFalse(thirdAction!.isChecked)
        XCTAssertEqual(thirdAction!.toggledCharacter, "x")
    }

    // MARK: - Clicking Outside Prefix (On Text Content)

    func testClickingOnTaskDescriptionDoesNotToggle() {
        let text = "- [ ] buy lemons and apples"
        let nsString = text as NSString

        // Character offset of "lemons"
        let lemonsPos = nsString.range(of: "lemons").location
        XCTAssertNil(CheckboxToggle.toggleAction(in: text, at: lemonsPos))

        // Character offset of "buy"
        let buyPos = nsString.range(of: "buy").location
        XCTAssertNil(CheckboxToggle.toggleAction(in: text, at: buyPos))
    }

    // MARK: - Code Fences

    func testCodeFenceSuppression() {
        let text = """
        ```markdown
        - [ ] code example
        ```
        """
        let nsString = text as NSString
        let codeOffset = nsString.range(of: "- [ ] code example").location + 2
        XCTAssertNil(CheckboxToggle.toggleAction(in: text, at: codeOffset))
    }

    // MARK: - Non-Checkbox Lines

    func testNonCheckboxLinesReturnNil() {
        XCTAssertNil(CheckboxToggle.toggleAction(in: "# Heading", at: 2))
        XCTAssertNil(CheckboxToggle.toggleAction(in: "Regular prose", at: 5))
        XCTAssertNil(CheckboxToggle.toggleAction(in: "[Link text](https://example.com)", at: 1))
        XCTAssertNil(CheckboxToggle.toggleAction(in: "- bullet without box", at: 0))
        XCTAssertNil(CheckboxToggle.toggleAction(in: "1. Numbered item", at: 0))
    }

    // MARK: - Card Gate Scenario

    func testCardGateSequence() {
        // "Click inside the `[ ]` of `- [ ] buy lemons`. The line becomes `- [x] buy lemons`."
        var text = "- [ ] buy lemons"
        let clickIndex = 3 // inside [ ]
        let toggle1 = CheckboxToggle.toggleAction(in: text, at: clickIndex)
        XCTAssertNotNil(toggle1)

        let nsString1 = text as NSString
        text = nsString1.replacingCharacters(in: toggle1!.replacementRange, with: toggle1!.replacementText)
        XCTAssertEqual(text, "- [x] buy lemons")

        // Clicking again toggles back to "- [ ] buy lemons"
        let toggle2 = CheckboxToggle.toggleAction(in: text, at: clickIndex)
        XCTAssertNotNil(toggle2)

        let nsString2 = text as NSString
        text = nsString2.replacingCharacters(in: toggle2!.replacementRange, with: toggle2!.replacementText)
        XCTAssertEqual(text, "- [ ] buy lemons")
    }
}
