import XCTest
#if canImport(AppKit)
import AppKit
#endif
@testable import BANALCore

final class SmartPasteTests: XCTestCase {
    func testHTTPURLValidation() {
        XCTAssertNotNil(SmartPaste.isHTTPURL("https://apple.com"))
        XCTAssertNotNil(SmartPaste.isHTTPURL("http://localhost:3000/path?key=val#hash"))
        XCTAssertNotNil(SmartPaste.isHTTPURL("   https://example.org/test   \n"))

        XCTAssertNil(SmartPaste.isHTTPURL(""))
        XCTAssertNil(SmartPaste.isHTTPURL("   "))
        XCTAssertNil(SmartPaste.isHTTPURL("not a url"))
        XCTAssertNil(SmartPaste.isHTTPURL("ftp://files.example.com"))
        XCTAssertNil(SmartPaste.isHTTPURL("file:///path/to/file"))
        XCTAssertNil(SmartPaste.isHTTPURL("https://apple.com and more text"))
        XCTAssertNil(SmartPaste.isHTTPURL("https://apple.com\nhttps://google.com"))
    }

    func testURLWrappingOverSelection() {
        let link = SmartPaste.linkWrapped(selectedText: "Apple", urlString: "https://apple.com")
        XCTAssertEqual(link, "[Apple](https://apple.com)")

        let trimmedLink = SmartPaste.linkWrapped(selectedText: "Search Engine", urlString: "  https://google.com/  \n")
        XCTAssertEqual(trimmedLink, "[Search Engine](https://google.com/)")

        XCTAssertNil(SmartPaste.linkWrapped(selectedText: "", urlString: "https://apple.com"))
        XCTAssertNil(SmartPaste.linkWrapped(selectedText: "Apple", urlString: "not a url"))
    }

    func testCleanMarkdownFromHTML() {
        let html = "<p>Here is <b>bold</b> and <a href=\"https://apple.com\">Apple</a>.</p>"
        let md = SmartPaste.cleanMarkdown(fromHTML: html)
        XCTAssertEqual(md, "Here is **bold** and [Apple](https://apple.com).")

        XCTAssertNil(SmartPaste.cleanMarkdown(fromHTML: ""))
        XCTAssertNil(SmartPaste.cleanMarkdown(fromHTML: "   <div></div>   "))
    }

    #if canImport(AppKit)
    func testCleanMarkdownFromRTFData() {
        let attrString = NSAttributedString(
            string: "Rich text with bold",
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 16)
            ]
        )
        guard let rtfData = try? attrString.data(
            from: NSRange(location: 0, length: attrString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else {
            XCTFail("Failed to create test RTF data")
            return
        }

        let md = SmartPaste.cleanMarkdown(fromRTFData: rtfData)
        XCTAssertNotNil(md)
        XCTAssertTrue(md?.contains("Rich text with bold") == true)
    }
    #endif
}
