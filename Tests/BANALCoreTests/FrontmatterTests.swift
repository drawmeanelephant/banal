import XCTest
@testable import BANALCore

final class FrontmatterTests: XCTestCase {
    func testParseAndSerializeRoundTrip() throws {
        let source = """
        ---
        title: Shopping
        created: 2026-08-18T16:00:00Z
        updated: 2026-08-18T16:30:00Z
        tags: [life, errands]
        published: true
        ---

        Buy milk.
        """
        let parsed = try FrontmatterCodec.parse(source)
        XCTAssertTrue(parsed.hasFrontmatter)
        XCTAssertEqual(parsed.frontmatter.title, "Shopping")
        XCTAssertEqual(parsed.frontmatter.tags, ["life", "errands"])
        XCTAssertTrue(parsed.frontmatter.published)
        XCTAssertEqual(parsed.frontmatter.created, DateFormatting.date(from: "2026-08-18T16:00:00Z"))
        XCTAssertTrue(parsed.body.contains("Buy milk."))

        let encoded = FrontmatterCodec.serialize(frontmatter: parsed.frontmatter, body: parsed.body)
        let again = try FrontmatterCodec.parse(encoded)
        XCTAssertEqual(again.frontmatter.title, "Shopping")
        XCTAssertEqual(again.frontmatter.tags, ["life", "errands"])
        XCTAssertTrue(again.frontmatter.published)
        XCTAssertTrue(again.body.contains("Buy milk."))
    }

    func testMissingFrontmatterIsEntireBody() throws {
        let source = "# Just a page\n\nHello.\n"
        let parsed = try FrontmatterCodec.parse(source)
        XCTAssertFalse(parsed.hasFrontmatter)
        XCTAssertEqual(parsed.body, source)
        XCTAssertEqual(parsed.bodyOffset, 0)
        XCTAssertEqual(parsed.frontmatter, .empty)
    }

    func testUnknownKeysArePreserved() throws {
        let source = """
        ---
        title: Keep
        published: false
        mood: quiet
        ---

        body
        """
        let parsed = try FrontmatterCodec.parse(source)
        XCTAssertEqual(parsed.frontmatter.extras, [FrontmatterExtra(key: "mood", rawValue: "quiet")])
        let encoded = FrontmatterCodec.serialize(frontmatter: parsed.frontmatter, body: parsed.body)
        XCTAssertTrue(encoded.contains("mood: quiet"))
    }

    func testUnclosedFenceFails() {
        XCTAssertThrowsError(try FrontmatterCodec.parse("---\ntitle: X\n")) { error in
            XCTAssertEqual(error as? FrontmatterError, .unclosedFence)
        }
    }

    func testDuplicateKeyFails() {
        XCTAssertThrowsError(try FrontmatterCodec.parse("---\ntitle: A\ntitle: B\n---\n")) { error in
            guard case FrontmatterError.duplicateKey("title", line: 3) = error else {
                return XCTFail("expected duplicateKey, got \(error)")
            }
        }
    }

    func testQuotedTags() throws {
        let parsed = try FrontmatterCodec.parse("---\ntags: [hello world, \"a,b\"]\n---\n")
        XCTAssertEqual(parsed.frontmatter.tags, ["hello world", "a,b"])
    }

    func testNoteIOWriteAndLoad() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-frontmatter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent("hello.md")
        let now = DateFormatting.date(from: "2026-08-18T12:00:00Z")!
        var note = Note(
            id: "hello",
            fileURL: url,
            title: "Hello",
            body: "\nWorld\n",
            created: now,
            updated: now,
            tags: ["greetings"],
            published: false,
            modifiedAt: now
        )
        note = try NoteIO.write(note)
        XCTAssertFalse(note.contentFingerprint.isEmpty)

        let loaded = try NoteIO.load(url: url, vaultURL: root)
        XCTAssertEqual(loaded.title, "Hello")
        XCTAssertEqual(loaded.tags, ["greetings"])
        XCTAssertTrue(loaded.body.contains("World"))
        XCTAssertEqual(loaded.id, "hello")
        XCTAssertFalse(loaded.published)
        XCTAssertEqual(loaded.contentFingerprint, note.contentFingerprint)
    }
}
