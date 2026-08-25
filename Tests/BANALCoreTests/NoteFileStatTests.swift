import XCTest
@testable import BANALCore

final class NoteFileStatTests: XCTestCase {
    private func makeNote(modifiedAt: Date, fileSize: Int?) -> Note {
        Note(
            id: "a.md",
            fileURL: URL(fileURLWithPath: "/tmp/a.md"),
            title: "A",
            body: "\n",
            created: modifiedAt,
            updated: modifiedAt,
            modifiedAt: modifiedAt,
            fileSize: fileSize
        )
    }

    func testMatchesNoteWithSameMtimeAndSize() {
        let mtime = Date(timeIntervalSince1970: 1_700_000_000)
        let stat = NoteFileStat(modifiedAt: mtime, fileSize: 42)
        XCTAssertTrue(stat.matches(makeNote(modifiedAt: mtime, fileSize: 42)))
    }

    func testRejectsDifferentMtime() {
        let mtime = Date(timeIntervalSince1970: 1_700_000_000)
        let stat = NoteFileStat(modifiedAt: mtime, fileSize: 42)
        XCTAssertFalse(stat.matches(makeNote(modifiedAt: mtime.addingTimeInterval(1), fileSize: 42)))
    }

    func testRejectsDifferentSize() {
        let mtime = Date(timeIntervalSince1970: 1_700_000_000)
        let stat = NoteFileStat(modifiedAt: mtime, fileSize: 42)
        XCTAssertFalse(stat.matches(makeNote(modifiedAt: mtime, fileSize: 43)))
    }

    func testRejectsNoteWithoutRecordedSize() {
        let mtime = Date(timeIntervalSince1970: 1_700_000_000)
        let stat = NoteFileStat(modifiedAt: mtime, fileSize: 42)
        XCTAssertFalse(stat.matches(makeNote(modifiedAt: mtime, fileSize: nil)))
    }

    func testInitFromURLAgreesWithNoteIOLoad() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("banal-stat-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("plain.md")
        try Data("abc1234".utf8).write(to: url)

        let stat = try XCTUnwrap(NoteFileStat(url: url))
        XCTAssertEqual(stat.fileSize, 7)

        // The stat taken separately must match what NoteIO.load records —
        // mtime equality across two resourceValues reads is the whole trick.
        let note = try NoteIO.load(url: url, vaultURL: dir)
        XCTAssertTrue(stat.matches(note), "a fresh stat must match the freshly loaded note")
    }

    func testInitFromMissingURLReturnsNil() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("gone-\(UUID().uuidString).md")
        XCTAssertNil(NoteFileStat(url: missing))
    }
}
