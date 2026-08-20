import AppKit
@testable import BANALCore
import XCTest

final class CopyAsTests: XCTestCase {

    // MARK: - Markdown Copy Tests

    func testCopyAsMarkdownSnippet() {
        let snippet = "## Section Title\n\nA paragraph with **bold** and *italic* text."
        let payload = CopyAsConverter.convert(snippet, format: .markdown, language: .markdown)

        XCTAssertEqual(payload.format, .markdown)
        XCTAssertEqual(payload.plainText, snippet)
        XCTAssertNil(payload.rtfData)
        XCTAssertNil(payload.html)
    }

    func testCopyAsMarkdownFullNoteStripsFrontmatter() {
        let noteSource = """
        ---
        title: Hello World
        created: 2026-08-19
        tags: [journal, test]
        ---

        # Hello World

        This is the body of the note.
        """

        let payload = CopyAsConverter.convert(noteSource, format: .markdown, language: .markdown)
        XCTAssertEqual(payload.format, .markdown)
        XCTAssertTrue(payload.plainText.contains("# Hello World"))
        XCTAssertTrue(payload.plainText.contains("This is the body of the note."))
        XCTAssertFalse(payload.plainText.contains("tags: [journal, test]"))
    }

    // MARK: - Rich Text (RTF) Tests

    func testCopyAsRichTextFormatting() throws {
        let markdown = """
        # Big Header
        ## Subheader
        A paragraph with **bold text**, *italic text*, `inline code`, ~~strikethrough~~, and [Apple](https://apple.com).

        > This is a quote.

        - Bullet Item 1
        - Bullet Item 2

        1. Numbered Item 1
        2. Numbered Item 2

        ```swift
        let x = 42
        ```
        """

        let payload = CopyAsConverter.convert(markdown, format: .richText, language: .markdown)
        XCTAssertEqual(payload.format, .richText)
        XCTAssertFalse(payload.plainText.isEmpty)
        XCTAssertNotNil(payload.rtfData)

        guard let rtfData = payload.rtfData else {
            XCTFail("RTF data should not be nil")
            return
        }

        // Verify that RTF data is valid and reconstructs into an NSAttributedString
        let attr = try NSAttributedString(
            data: rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )

        let plain = attr.string
        XCTAssertTrue(plain.contains("Big Header"))
        XCTAssertTrue(plain.contains("Subheader"))
        XCTAssertTrue(plain.contains("bold text"))
        XCTAssertTrue(plain.contains("italic text"))
        XCTAssertTrue(plain.contains("inline code"))
        XCTAssertTrue(plain.contains("Bullet Item 1"))
        XCTAssertTrue(plain.contains("Numbered Item 1"))
        XCTAssertTrue(plain.contains("let x = 42"))
    }

    func testCopyAsRichTextTextile() throws {
        let textile = """
        h1. Textile Heading

        p. A paragraph with *bold* and _italic_ and @code@.

        * First bullet
        * Second bullet

        # First numbered
        # Second numbered
        """

        let payload = CopyAsConverter.convert(textile, format: .richText, language: .textile)
        XCTAssertEqual(payload.format, .richText)
        XCTAssertNotNil(payload.rtfData)

        let attr = try NSAttributedString(
            data: payload.rtfData!,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
        XCTAssertTrue(attr.string.contains("Textile Heading"))
        XCTAssertTrue(attr.string.contains("bold"))
        XCTAssertTrue(attr.string.contains("First bullet"))
    }

    func testCopyAsRichTextCooklang() throws {
        let cooklang = """
        >> title: Classic Risotto
        >> servings: 4
        >> time: 30 minutes

        In a #pan{}, heat @olive oil{2%tbsp} and add @onion{1}.
        Add @arborio rice{300%g} and stir until translucent.
        Gradually add @vegetable stock{1%L} while stirring constantly for ~{20%minutes}.
        """

        let payload = CopyAsConverter.convert(cooklang, format: .richText, language: .cooklang)
        XCTAssertEqual(payload.format, .richText)
        XCTAssertNotNil(payload.rtfData)

        let attr = try NSAttributedString(
            data: payload.rtfData!,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
        let plain = attr.string
        XCTAssertTrue(plain.contains("Classic Risotto"))
        XCTAssertTrue(plain.contains("Ingredients"))
        XCTAssertTrue(plain.contains("olive oil"))
        XCTAssertTrue(plain.contains("arborio rice"))
        XCTAssertTrue(plain.contains("Instructions"))
    }

    // MARK: - HTML Copy Tests

    func testCopyAsHTMLMarkdown() {
        let markdown = """
        # Main Title
        ## Subtitle

        This is a paragraph with **strong**, *emphasis*, `code`, ~~deleted~~, and [Link](https://example.com).

        > Quoted message

        - Item A
        - Item B

        1. Step One
        2. Step Two

        ---

        ```javascript
        console.log("hello");
        ```
        """

        let payload = CopyAsConverter.convert(markdown, format: .html, language: .markdown)
        XCTAssertEqual(payload.format, .html)
        XCTAssertNotNil(payload.html)

        guard let html = payload.html else {
            XCTFail("HTML should not be nil")
            return
        }

        XCTAssertTrue(html.contains("<h1>Main Title</h1>"))
        XCTAssertTrue(html.contains("<h2>Subtitle</h2>"))
        XCTAssertTrue(html.contains("<strong>strong</strong>"))
        XCTAssertTrue(html.contains("<em>emphasis</em>"))
        XCTAssertTrue(html.contains("<code>code</code>"))
        XCTAssertTrue(html.contains("<del>deleted</del>"))
        XCTAssertTrue(html.contains("<a href=\"https://example.com\">Link</a>"))
        XCTAssertTrue(html.contains("<blockquote><p>Quoted message</p></blockquote>"))
        XCTAssertTrue(html.contains("<ul>\n  <li>Item A</li>\n  <li>Item B</li>\n</ul>"))
        XCTAssertTrue(html.contains("<ol>\n  <li>Step One</li>\n  <li>Step Two</li>\n</ol>"))
        XCTAssertTrue(html.contains("<hr>"))
        XCTAssertTrue(html.contains("<pre><code>console.log(&quot;hello&quot;);</code></pre>"))
    }

    func testCopyAsHTMLTextile() {
        let textile = """
        h1. Heading 1
        h2. Heading 2

        p. Paragraph with *bold text* and _italic text_ and @inline code@.

        * Bullet 1
        * Bullet 2

        # Number 1
        # Number 2

        bc. code line
        """

        let payload = CopyAsConverter.convert(textile, format: .html, language: .textile)
        XCTAssertEqual(payload.format, .html)
        XCTAssertNotNil(payload.html)

        guard let html = payload.html else {
            XCTFail("HTML should not be nil")
            return
        }

        XCTAssertTrue(html.contains("<h1>Heading 1</h1>"))
        XCTAssertTrue(html.contains("<h2>Heading 2</h2>"))
        XCTAssertTrue(html.contains("<strong>bold text</strong>"))
        XCTAssertTrue(html.contains("<em>italic text</em>"))
        XCTAssertTrue(html.contains("<code>inline code</code>"))
        XCTAssertTrue(html.contains("<ul>\n  <li>Bullet 1</li>\n  <li>Bullet 2</li>\n</ul>"))
        XCTAssertTrue(html.contains("<ol>\n  <li>Number 1</li>\n  <li>Number 2</li>\n</ol>"))
        XCTAssertTrue(html.contains("<pre><code>code line</code></pre>"))
    }

    func testCopyAsHTMLCooklang() {
        let cooklang = """
        >> title: Scrambled Eggs

        Melt @butter{1%tbsp} in a #skillet{}.
        Beat @eggs{3} and pour into pan.
        Cook for ~{3%minutes}.
        """

        let payload = CopyAsConverter.convert(cooklang, format: .html, language: .cooklang)
        XCTAssertEqual(payload.format, .html)
        XCTAssertNotNil(payload.html)

        guard let html = payload.html else {
            XCTFail("HTML should not be nil")
            return
        }

        XCTAssertTrue(html.contains("<h1>Scrambled Eggs</h1>"))
        XCTAssertTrue(html.contains("<h2>Ingredients</h2>"))
        XCTAssertTrue(html.contains("<li>1 tbsp butter</li>") || html.contains("butter"))
        XCTAssertTrue(html.contains("<li>3 eggs</li>") || html.contains("eggs"))
        XCTAssertTrue(html.contains("<h2>Cookware</h2>"))
        XCTAssertTrue(html.contains("<li>skillet</li>"))
        XCTAssertTrue(html.contains("<h2>Instructions</h2>"))
    }

    // MARK: - Pasteboard Tests

    func testPasteboardWritingMarkdown() {
        let pasteboard = NSPasteboard(name: .init(UUID().uuidString))
        let payload = CopyAsPayload(format: .markdown, plainText: "# Title\n\nSome text")

        let success = CopyAsConverter.copy(payload, to: pasteboard)
        XCTAssertTrue(success)
        XCTAssertEqual(pasteboard.string(forType: .string), "# Title\n\nSome text")
        XCTAssertNil(pasteboard.data(forType: .rtf))
        XCTAssertNil(pasteboard.string(forType: .html))
    }

    func testPasteboardWritingRichText() {
        let pasteboard = NSPasteboard(name: .init(UUID().uuidString))
        let sampleRTF = "{\\rtf1\\ansi Sample RTF}".data(using: .utf8)
        let payload = CopyAsPayload(format: .richText, plainText: "Sample Plain Text", rtfData: sampleRTF)

        let success = CopyAsConverter.copy(payload, to: pasteboard)
        XCTAssertTrue(success)
        XCTAssertEqual(pasteboard.string(forType: .string), "Sample Plain Text")
        XCTAssertEqual(pasteboard.data(forType: .rtf), sampleRTF)
    }

    func testPasteboardWritingHTML() {
        let pasteboard = NSPasteboard(name: .init(UUID().uuidString))
        let htmlSnippet = "<h1>Heading</h1><p>Body</p>"
        let payload = CopyAsPayload(format: .html, plainText: "Heading\n\nBody", html: htmlSnippet)

        let success = CopyAsConverter.copy(payload, to: pasteboard)
        XCTAssertTrue(success)
        XCTAssertEqual(pasteboard.string(forType: .string), "Heading\n\nBody")
        XCTAssertEqual(pasteboard.string(forType: .html), htmlSnippet)
    }
}
