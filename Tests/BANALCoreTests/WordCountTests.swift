import XCTest
@testable import BANALCore

final class WordCountTests: XCTestCase {
    func testEmptyString() {
        let stats = WordCount.count(in: "")
        XCTAssertEqual(stats.words, 0)
        XCTAssertEqual(stats.characters, 0)
        XCTAssertEqual(stats.formattedDescription, "0 words · 0 characters")
    }

    func testSingleWord() {
        let stats = WordCount.count(in: "BANAL")
        XCTAssertEqual(stats.words, 1)
        XCTAssertEqual(stats.characters, 5)
        XCTAssertEqual(stats.formattedDescription, "1 word · 5 characters")
    }

    func testMultipleWordsAndPunctuation() {
        let stats = WordCount.count(in: "The quick brown fox jumps over the lazy dog.")
        XCTAssertEqual(stats.words, 9)
        XCTAssertEqual(stats.characters, 44)
        XCTAssertEqual(stats.formattedDescription, "9 words · 44 characters")
    }

    func testMultilineAndWhitespace() {
        let text = """
        First paragraph here.

        Second paragraph with more words!
        """
        let stats = WordCount.count(in: text)
        XCTAssertEqual(stats.words, 8)
        XCTAssertEqual(stats.characters, text.count)
    }

    func testCardGateDescriptionFormat() {
        let stats = WordCountStats(words: 342, characters: 1840)
        XCTAssertEqual(stats.formattedDescription, "342 words · 1,840 characters")

        let singleStats = WordCountStats(words: 1, characters: 1)
        XCTAssertEqual(singleStats.formattedDescription, "1 word · 1 character")
    }
}
