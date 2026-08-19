import XCTest
@testable import BANALCore

final class WhisperScanTests: XCTestCase {

    private func kinds(_ marks: [WhisperMark]) -> [WhisperMarkKind] {
        marks.map(\.kind)
    }

    // MARK: - Markdown headings

    func testMarkdownHeadingMarksSigilAndContent() {
        let marks = WhisperScan.marks(in: "# Title", language: .markdown)
        XCTAssertEqual(kinds(marks), [.sigil, .heading])
        XCTAssertEqual(marks[0].range, NSRange(location: 0, length: 1)) // "#"
        XCTAssertEqual(marks[1].range, NSRange(location: 2, length: 5)) // "Title"
    }

    func testMarkdownHeadingsUpToSixAndNoFalseHeading() {
        let marks = WhisperScan.marks(in: "## Heading\n### Deep\n####### nope\n#tag", language: .markdown)
        XCTAssertEqual(kinds(marks), [.sigil, .heading, .sigil, .heading])
        XCTAssertEqual(marks[0].range, NSRange(location: 0, length: 2))
        XCTAssertEqual(marks[1].range, NSRange(location: 3, length: 7))
        XCTAssertEqual(marks[2].range, NSRange(location: 11, length: 3))
        XCTAssertEqual(marks[3].range, NSRange(location: 15, length: 4))
    }

    // MARK: - Markdown emphasis

    func testMarkdownBoldPair() {
        let marks = WhisperScan.marks(in: "a **bold** c", language: .markdown)
        XCTAssertEqual(kinds(marks), [.sigil, .sigil])
        XCTAssertEqual(marks[0].range, NSRange(location: 2, length: 2))
        XCTAssertEqual(marks[1].range, NSRange(location: 8, length: 2))
    }

    func testMarkdownItalicAndUnderscorePairs() {
        let marks = WhisperScan.marks(in: "*a* _b_", language: .markdown)
        XCTAssertEqual(kinds(marks), [.sigil, .sigil, .sigil, .sigil])
        XCTAssertEqual(marks[0].range, NSRange(location: 0, length: 1))
        XCTAssertEqual(marks[1].range, NSRange(location: 2, length: 1))
        XCTAssertEqual(marks[2].range, NSRange(location: 4, length: 1))
        XCTAssertEqual(marks[3].range, NSRange(location: 6, length: 1))
    }

    func testMarkdownLoneAsteriskStaysUnpaired() {
        let marks = WhisperScan.marks(in: "* item\na * b", language: .markdown)
        XCTAssertTrue(marks.isEmpty)
    }

    func testMarkdownDoubleStarsWinOverSingles() {
        let marks = WhisperScan.marks(in: "**bold**", language: .markdown)
        XCTAssertEqual(kinds(marks), [.sigil, .sigil])
        XCTAssertEqual(marks[0].range, NSRange(location: 0, length: 2))
        XCTAssertEqual(marks[1].range, NSRange(location: 6, length: 2))
    }

    // MARK: - Markdown links

    func testMarkdownLink() {
        let marks = WhisperScan.marks(in: "[label](url)", language: .markdown)
        XCTAssertEqual(kinds(marks), [.sigil, .sigil, .sigil])
        XCTAssertEqual(marks[0].range, NSRange(location: 0, length: 1)) // "["
        XCTAssertEqual(marks[1].range, NSRange(location: 6, length: 2)) // "]("
        XCTAssertEqual(marks[2].range, NSRange(location: 11, length: 1)) // ")"
    }

    // MARK: - Markdown code spans and fences

    func testMarkdownFencedCodeHasNoMarks() {
        let source = "```\n# hidden\n```\n# shown"
        let marks = WhisperScan.marks(in: source, language: .markdown)
        XCTAssertEqual(kinds(marks), [.sigil, .heading])
        XCTAssertEqual(marks[0].range, NSRange(location: 17, length: 1))
        XCTAssertEqual(marks[1].range, NSRange(location: 19, length: 5))
    }

    func testMarkdownInlineCodeSpanBlocksEmphasis() {
        let source = "`*a*` and *b*"
        let marks = WhisperScan.marks(in: source, language: .markdown)
        XCTAssertEqual(kinds(marks), [.sigil, .sigil])
        XCTAssertEqual(marks[0].range, NSRange(location: 10, length: 1))
        XCTAssertEqual(marks[1].range, NSRange(location: 12, length: 1))
    }

    // MARK: - Textile

    func testTextileHeadingEmphasisAndLink() {
        let source = "h2. Title\n*bold* \"label\":url"
        let marks = WhisperScan.marks(in: source, language: .textile)
        XCTAssertEqual(kinds(marks), [.sigil, .heading, .sigil, .sigil, .sigil, .sigil])
        XCTAssertEqual(marks[0].range, NSRange(location: 0, length: 3)) // "h2."
        XCTAssertEqual(marks[1].range, NSRange(location: 4, length: 5)) // "Title"
        XCTAssertEqual(marks[2].range, NSRange(location: 10, length: 1)) // "*"
        XCTAssertEqual(marks[3].range, NSRange(location: 15, length: 1)) // "*"
        XCTAssertEqual(marks[4].range, NSRange(location: 17, length: 1)) // "\""
        XCTAssertEqual(marks[5].range, NSRange(location: 23, length: 2)) // "\":"
    }

    func testTextileBlockquoteNotMarked() {
        let marks = WhisperScan.marks(in: ">>> quoted *text*", language: .textile)
        XCTAssertTrue(marks.isEmpty)
    }

    // MARK: - Cooklang

    func testCooklangSigils() {
        let source = "Add @salt{1%tsp} to #pan{} and ~{5 min}."
        let marks = WhisperScan.marks(in: source, language: .cooklang)
        XCTAssertEqual(kinds(marks), Array(repeating: .sigil, count: 9))
        let expected: [NSRange] = [
            NSRange(location: 4, length: 1),   // "@"
            NSRange(location: 9, length: 1),   // "{"
            NSRange(location: 15, length: 1),  // "}"
            NSRange(location: 20, length: 1),  // "#"
            NSRange(location: 24, length: 1),  // "{"
            NSRange(location: 25, length: 1),  // "}"
            NSRange(location: 31, length: 1),  // "~"
            NSRange(location: 32, length: 1),  // "{"
            NSRange(location: 38, length: 1),  // "}"
        ]
        XCTAssertEqual(marks.map(\.range), expected)
    }

    func testCooklangBareHashUnmarked() {
        // "# not cookware" has no brace, so the bare # is not cookware.
        let marks = WhisperScan.marks(in: "# not cookware\n@x{}", language: .cooklang)
        XCTAssertEqual(kinds(marks), [.sigil, .sigil, .sigil])
        XCTAssertEqual(marks[0].range, NSRange(location: 15, length: 1))
        XCTAssertEqual(marks[1].range, NSRange(location: 17, length: 1))
        XCTAssertEqual(marks[2].range, NSRange(location: 18, length: 1))
    }

    func testCooklangMetadataLine() {
        let marks = WhisperScan.marks(in: ">> title: Risotto", language: .cooklang)
        XCTAssertEqual(kinds(marks), [.sigil])
        XCTAssertEqual(marks[0].range, NSRange(location: 0, length: 2))
    }

    // MARK: - Purity and encoding

    func testMarksNeverMutateAndRangesAreValid() {
        let source = "# Title\nAdd @salt{1%tsp}.\n"
        let copy = source
        let marks = WhisperScan.marks(in: source, language: .cooklang)
        XCTAssertEqual(source, copy)
        let utf16Length = (source as NSString).length
        for mark in marks {
            XCTAssertLessThanOrEqual(mark.range.location + mark.range.length, utf16Length)
        }
    }

    func testMarkRangesAreUTF16() {
        // 🍝 is two UTF-16 units; the heading must land after it, not on it.
        let marks = WhisperScan.marks(in: "🍝\n# Title", language: .markdown)
        XCTAssertEqual(kinds(marks), [.sigil, .heading])
        XCTAssertEqual(marks[0].range, NSRange(location: 3, length: 1))
        XCTAssertEqual(marks[1].range, NSRange(location: 5, length: 5))
    }

    // MARK: - Heading Lines & Paragraph Spacing

    func testMarkdownHeadingLineTopException() {
        let text = "# Title\nParagraph text."
        let headings = WhisperScan.headingLines(in: text, language: .markdown)
        XCTAssertEqual(headings.count, 1)
        XCTAssertEqual(headings[0].level, 1)
        XCTAssertTrue(headings[0].isTop)
        XCTAssertEqual(headings[0].range, NSRange(location: 0, length: 7))
    }

    func testMarkdownHeadingLineTopWithLeadingWhitespace() {
        let text = "\n  \n# Title\nParagraph"
        let headings = WhisperScan.headingLines(in: text, language: .markdown)
        XCTAssertEqual(headings.count, 1)
        XCTAssertEqual(headings[0].level, 1)
        XCTAssertTrue(headings[0].isTop)
        XCTAssertEqual(headings[0].range, NSRange(location: 4, length: 7))
    }

    func testMarkdownHeadingLineNotTopAfterProse() {
        let text = "Intro paragraph.\n\n## Section One\nBody text."
        let headings = WhisperScan.headingLines(in: text, language: .markdown)
        XCTAssertEqual(headings.count, 1)
        XCTAssertEqual(headings[0].level, 2)
        XCTAssertFalse(headings[0].isTop)
        XCTAssertEqual(headings[0].range, NSRange(location: 18, length: 14))
    }

    func testMarkdownHeadingLevelsOneThroughSix() {
        let text = "# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6\n####### H7"
        let headings = WhisperScan.headingLines(in: text, language: .markdown)
        XCTAssertEqual(headings.count, 6)
        XCTAssertEqual(headings.map(\.level), [1, 2, 3, 4, 5, 6])
        XCTAssertTrue(headings[0].isTop)
        XCTAssertFalse(headings[1].isTop)
        XCTAssertFalse(headings[2].isTop)
        XCTAssertFalse(headings[3].isTop)
        XCTAssertFalse(headings[4].isTop)
        XCTAssertFalse(headings[5].isTop)
    }

    func testMarkdownHeadingLinesInsideCodeFenceIgnored() {
        let text = "```\n# Hidden In Backticks\n```\n# Visible\n~~~\n## Hidden In Tildes\n~~~\n### Also Visible"
        let headings = WhisperScan.headingLines(in: text, language: .markdown)
        XCTAssertEqual(headings.count, 2)
        XCTAssertEqual(headings[0].level, 1)
        XCTAssertEqual(headings[1].level, 3)
    }

    func testTextileHeadingLines() {
        let text = "h1. Main Title\nSome content.\nh3. Sub Heading"
        let headings = WhisperScan.headingLines(in: text, language: .textile)
        XCTAssertEqual(headings.count, 2)
        XCTAssertEqual(headings[0].level, 1)
        XCTAssertTrue(headings[0].isTop)
        XCTAssertEqual(headings[0].range, NSRange(location: 0, length: 14))
        XCTAssertEqual(headings[1].level, 3)
        XCTAssertFalse(headings[1].isTop)
    }

    func testCooklangHasNoHeadingLines() {
        let text = ">> title: Risotto\nAdd @rice{300%g} to #pan{} and cook."
        let headings = WhisperScan.headingLines(in: text, language: .cooklang)
        XCTAssertTrue(headings.isEmpty)
    }

    func testHeadingSpacingMetricsValues() {
        XCTAssertEqual(HeadingSpacingMetrics.spacingBefore, 10, accuracy: 2.0)
        XCTAssertEqual(HeadingSpacingMetrics.spacingAfter, 4, accuracy: 1.0)
    }

    func testHeadingLineUTF16EmojiOffset() {
        let text = "🍝\n# Delicious Pasta"
        let headings = WhisperScan.headingLines(in: text, language: .markdown)
        XCTAssertEqual(headings.count, 1)
        XCTAssertEqual(headings[0].level, 1)
        XCTAssertFalse(headings[0].isTop)
        XCTAssertEqual(headings[0].range, NSRange(location: 3, length: 17))
    }
}
