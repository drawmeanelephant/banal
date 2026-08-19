import XCTest
@testable import BANALCore

final class HTMLToMarkdownTests: XCTestCase {
    func testCleanHTMLBoldAndItalic() {
        let html = "<b>bold</b> and <i>italic</i>"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "**bold** and *italic*")
    }

    func testStrongAndEmphasis() {
        let html = "<strong>strong text</strong> and <em>emphasized text</em>"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "**strong text** and *emphasized text*")
    }

    func testHTMLLinks() {
        let html = "<a href=\"https://example.com\">link</a>"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "[link](https://example.com)")
    }

    func testStrippingStylesSpansAndDivs() {
        let html = "<div style=\"color:red\" class=\"wrapper\"><span style=\"font-size:14px\">text</span></div>"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "text")
    }

    func testHeadings() {
        let html = "<h1>Heading 1</h1><h2>Heading 2</h2><h3>Heading 3</h3>"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "# Heading 1\n\n## Heading 2\n\n### Heading 3")
    }

    func testUnorderedList() {
        let html = "<ul><li>Alpha</li><li>Beta</li><li>Gamma</li></ul>"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "- Alpha\n- Beta\n- Gamma")
    }

    func testOrderedList() {
        let html = "<ol><li>First</li><li>Second</li><li>Third</li></ol>"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "1. First\n2. Second\n3. Third")
    }

    func testNestedLists() {
        let html = "<ul><li>Parent 1<ul><li>Child 1</li><li>Child 2</li></ul></li><li>Parent 2</li></ul>"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "- Parent 1\n  - Child 1\n  - Child 2\n- Parent 2")
    }

    func testBlockquote() {
        let html = "<blockquote><p>This is a quote.</p></blockquote>"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "> This is a quote.")
    }

    func testInlineCodeAndPreBlock() {
        let html = "<p>Here is <code>let a = 1</code> in text.</p><pre><code>func hello() {\n    print(\"world\")\n}</code></pre>"
        let md = HTMLToMarkdown.convert(html)
        let expected = "Here is `let a = 1` in text.\n\n```\nfunc hello() {\n    print(\"world\")\n}\n```"
        XCTAssertEqual(md, expected)
    }

    func testParagraphsAndBreaks() {
        let html = "<p>First paragraph.</p><p>Second paragraph<br>with a line break.</p>"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "First paragraph.\n\nSecond paragraph\nwith a line break.")
    }

    func testStrippingHeadScriptsAndStyles() {
        let html = """
        <html>
        <head><title>Ignore Me</title><style>body { color: black; }</style></head>
        <body>
        <script>alert("bad");</script>
        <!-- A comment -->
        <p>Visible content</p>
        </body>
        </html>
        """
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "Visible content")
    }

    func testEntityDecoding() {
        let html = "Tom &amp; Jerry &gt; Mickey &amp; Minnie &quot;Friends&quot; &#39;Forever&#39; &copy; 2026"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "Tom & Jerry > Mickey & Minnie \"Friends\" 'Forever' © 2026")
    }

    func testNumericEntities() {
        let html = "&#8220;Smart Quotes&#8221; and &#x2014; em dash"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "“Smart Quotes” and — em dash")
    }

    func testStrikethrough() {
        let html = "<s>deleted</s> <del>removed</del> <strike>struck</strike>"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "~~deleted~~ ~~removed~~ ~~struck~~")
    }

    func testImages() {
        let html = "<img src=\"https://example.com/photo.jpg\" alt=\"A photo\" />"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "![A photo](https://example.com/photo.jpg)")
    }

    func testEmptyOrWhitespaceHTML() {
        XCTAssertEqual(HTMLToMarkdown.convert(""), "")
        XCTAssertEqual(HTMLToMarkdown.convert("   \n\t  "), "")
        XCTAssertEqual(HTMLToMarkdown.convert("<div><span></span></div>"), "")
    }

    func testHorizontalRule() {
        let html = "<p>Above</p><hr><p>Below</p>"
        let md = HTMLToMarkdown.convert(html)
        XCTAssertEqual(md, "Above\n\n---\n\nBelow")
    }
}
