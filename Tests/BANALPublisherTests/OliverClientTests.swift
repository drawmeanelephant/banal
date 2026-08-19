import XCTest
@testable import BANALCore
@testable import BANALPublisher

final class OliverClientTests: XCTestCase {
    func testLocatorAcceptsConfiguredExecutable() {
        let sh = URL(fileURLWithPath: "/bin/sh")
        XCTAssertEqual(OliverLocator.resolve(configured: sh.path), sh)
    }

    func testLocatorIgnoresMissingConfiguredPathAndKeepsSearching() {
        let missing = "/tmp/banal-no-oliver-\(UUID().uuidString)"
        let found = OliverLocator.resolve(configured: missing)
        if let found {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: found.path))
        }
    }

    func testMissingBinaryThrows() {
        let url = URL(fileURLWithPath: "/tmp/banal-missing-oliver-\(UUID().uuidString)")
        XCTAssertThrowsError(try OliverClient(binaryURL: url).render("# Hello\n")) { error in
            XCTAssertEqual(error as? OliverError, .missingBinary)
        }
    }

    func testBodyForOliverStripsBANALFrontmatter() {
        let source = """
        ---
        title: Local Title
        created: 2026-08-18T16:00:00Z
        updated: 2026-08-18T16:30:00Z
        published: true
        ---

        # Hello
        """
        let body = OliverClient.bodyForOliver(source)
        XCTAssertTrue(body.contains("# Hello"))
        XCTAssertFalse(body.contains("title: Local Title"))
        XCTAssertFalse(body.hasPrefix("---"))
    }

    func testBodyForOliverLeavesBareMarkdownAlone() {
        let source = "# Just a page\n\nHello.\n"
        XCTAssertEqual(OliverClient.bodyForOliver(source), source)
    }

    func testRendersMarkdownHeadingToHTML() throws {
        let binary = OliverLocator.resolve()
        try XCTSkipUnless(binary != nil, "Oliver binary not on PATH or in a sibling checkout")
        let html = try OliverClient(binaryURL: binary!).render("# Hello\n").html
        XCTAssertTrue(html.contains("<h1>"), "expected a heading tag, got: \(html)")
        XCTAssertTrue(html.contains("Hello"), "expected heading text, got: \(html)")
    }

    func testRenderStripsFrontmatterSoOliverDoesNotSeeLocalKeys() throws {
        let binary = OliverLocator.resolve()
        try XCTSkipUnless(binary != nil, "Oliver binary not on PATH or in a sibling checkout")
        let source = """
        ---
        title: Local Title
        created: 2026-08-18T16:00:00Z
        updated: 2026-08-18T16:30:00Z
        published: true
        ---

        # Hello
        """
        let html = try OliverClient(binaryURL: binary!).render(source).html
        XCTAssertTrue(html.contains("<h1>"), "expected a heading tag, got: \(html)")
        XCTAssertTrue(html.contains("Hello"), "expected heading text, got: \(html)")
        XCTAssertFalse(html.contains("Local Title"), "Oliver must not render BANAL frontmatter: \(html)")
        XCTAssertFalse(html.lowercased().contains("<hr"), "fences must not become a thematic break: \(html)")
    }
}
