import XCTest
@testable import BANALCore

final class TranslationStateTests: XCTestCase {
    func testValidation() {
        XCTAssertFalse(TranslationState.isValidTranslationText(""))
        XCTAssertFalse(TranslationState.isValidTranslationText("   "))
        XCTAssertFalse(TranslationState.isValidTranslationText(" \n\t  \n"))
        XCTAssertTrue(TranslationState.isValidTranslationText("Hola"))
        XCTAssertTrue(TranslationState.isValidTranslationText("  Bonjour le monde!  "))
        XCTAssertTrue(TranslationState.isValidTranslationText("Risotto alla milanese"))
    }

    func testStateCanTranslate() {
        var state = TranslationState()
        XCTAssertFalse(state.canTranslate)

        state.selectedText = "  "
        XCTAssertFalse(state.canTranslate)

        state.selectedText = "El arroz con pollo está delicioso."
        XCTAssertTrue(state.canTranslate)
    }

    func testExtractSelectedTextValidRanges() {
        let text = "El veloz murciélago hindú comía feliz cardillo y kiwi."
        let nsString = text as NSString
        let murcielagoRange = nsString.range(of: "murciélago")

        let extracted = TranslationState.extractSelectedText(from: text, range: murcielagoRange)
        XCTAssertEqual(extracted, "murciélago")

        let wholeRange = NSRange(location: 0, length: nsString.length)
        XCTAssertEqual(TranslationState.extractSelectedText(from: text, range: wholeRange), text)
    }

    func testExtractSelectedTextInvalidRanges() {
        let text = "C'est la vie."
        XCTAssertNil(TranslationState.extractSelectedText(from: text, range: NSRange(location: NSNotFound, length: 0)))
        XCTAssertNil(TranslationState.extractSelectedText(from: text, range: NSRange(location: 0, length: 0)))
        XCTAssertNil(TranslationState.extractSelectedText(from: text, range: NSRange(location: 50, length: 5)))
        XCTAssertNil(TranslationState.extractSelectedText(from: text, range: NSRange(location: 5, length: 50)))
        XCTAssertNil(TranslationState.extractSelectedText(from: text, range: NSRange(location: -1, length: 4)))
    }

    func testExtractWithEmojisAndAccents() {
        let text = "🥘 Paella valenciana con azafrán y mariscos 🦐"
        let nsString = text as NSString
        let paellaRange = nsString.range(of: "Paella valenciana")
        XCTAssertEqual(TranslationState.extractSelectedText(from: text, range: paellaRange), "Paella valenciana")

        let azafranRange = nsString.range(of: "azafrán")
        XCTAssertEqual(TranslationState.extractSelectedText(from: text, range: azafranRange), "azafrán")
    }

    func testReplaceSelectedText() {
        let original = "Quisiera pedir una taza de café, por favor."
        let nsString = original as NSString
        let cafeRange = nsString.range(of: "una taza de café")

        guard let (replaced, newRange) = TranslationState.replaceSelectedText(
            in: original,
            range: cafeRange,
            with: "a cup of coffee"
        ) else {
            XCTFail("Failed to replace selected text")
            return
        }

        XCTAssertEqual(replaced, "Quisiera pedir a cup of coffee, por favor.")
        XCTAssertEqual(newRange.location, cafeRange.location + ("a cup of coffee" as NSString).length)
        XCTAssertEqual(newRange.length, 0)
    }

    func testReplaceSelectedTextAtEdges() {
        let original = "Buenos días a todos."
        let nsString = original as NSString

        // At beginning
        let startRange = nsString.range(of: "Buenos días")
        let startReplaced = TranslationState.replaceSelectedText(in: original, range: startRange, with: "Good morning")
        XCTAssertEqual(startReplaced?.result, "Good morning a todos.")
        XCTAssertEqual(startReplaced?.newRange.location, ("Good morning" as NSString).length)

        // At end
        let endRange = nsString.range(of: "a todos.")
        let endReplaced = TranslationState.replaceSelectedText(in: original, range: endRange, with: "everyone.")
        XCTAssertEqual(endReplaced?.result, "Buenos días everyone.")
    }

    func testReplaceInvalidRangeReturnsNil() {
        let original = "Simple text."
        XCTAssertNil(TranslationState.replaceSelectedText(in: original, range: NSRange(location: NSNotFound, length: 0), with: "foo"))
        XCTAssertNil(TranslationState.replaceSelectedText(in: original, range: NSRange(location: 50, length: 10), with: "foo"))
    }

    func testAvailabilityCheck() {
        if #available(macOS 15.0, *) {
            XCTAssertTrue(TranslationState.isSystemTranslationSupported)
        } else {
            XCTAssertFalse(TranslationState.isSystemTranslationSupported)
        }
    }
}
