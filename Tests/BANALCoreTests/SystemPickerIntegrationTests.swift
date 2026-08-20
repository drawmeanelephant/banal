import XCTest
#if canImport(AppKit)
import AppKit
#endif
@testable import BANALCore

final class SystemPickerIntegrationTests: XCTestCase {
    func testContactLinkInsertionFormatting() {
        let noteBody = "Meeting with  to discuss roadmap."
        let caretLocation = 13 // right after "Meeting with "

        let contactLink = ContactMarkdownFormatter.format(name: "John Appleseed", email: "john@apple.com")
        XCTAssertEqual(contactLink, "[John Appleseed](mailto:john@apple.com)")

        let nsBody = noteBody as NSString
        let newBody = nsBody.replacingCharacters(in: NSRange(location: caretLocation, length: 0), with: contactLink)
        XCTAssertEqual(newBody, "Meeting with [John Appleseed](mailto:john@apple.com) to discuss roadmap.")
    }

    func testFileLinkInsertionFormatting() {
        let noteBody = "Please see attached  for details."
        let caretLocation = 20

        let fileLink = AssetManager.fileLink(name: "Annual Report.pdf", relativePath: "assets/Annual Report.pdf")
        XCTAssertEqual(fileLink, "[Annual Report.pdf](assets/Annual Report.pdf)")

        let nsBody = noteBody as NSString
        let newBody = nsBody.replacingCharacters(in: NSRange(location: caretLocation, length: 0), with: fileLink)
        XCTAssertEqual(newBody, "Please see attached [Annual Report.pdf](assets/Annual Report.pdf) for details.")
    }

    func testFileLinkReplacesSelectedText() {
        let noteBody = "Download the quarterly report here."
        let selectedRange = (noteBody as NSString).range(of: "quarterly report")

        let fileLink = AssetManager.fileLink(name: "quarterly report", relativePath: "assets/q3-report.pdf")
        XCTAssertEqual(fileLink, "[quarterly report](assets/q3-report.pdf)")

        let nsBody = noteBody as NSString
        let newBody = nsBody.replacingCharacters(in: selectedRange, with: fileLink)
        XCTAssertEqual(newBody, "Download the [quarterly report](assets/q3-report.pdf) here.")
    }
}
