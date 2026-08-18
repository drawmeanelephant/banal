import XCTest
@testable import BANALCore

final class NotesFolderAccessTests: XCTestCase {
    func testNilIsFirstRun() {
        XCTAssertEqual(NotesFolderAccess.resolve(remembered: nil), .firstRun)
    }

    func testExistingDirectoryIsReady() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("banal-access-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(NotesFolderAccess.resolve(remembered: url), .ready(url))
    }

    func testMissingDirectoryIsMissing() {
        let url = URL(fileURLWithPath: "/tmp/banal-does-not-exist-\(UUID().uuidString)", isDirectory: true)
        XCTAssertEqual(NotesFolderAccess.resolve(remembered: url), .missing(url))
    }

    func testFileIsMissingNotReady() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("banal-access-\(UUID().uuidString).txt")
        try Data("nope".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(NotesFolderAccess.resolve(remembered: url), .missing(url))
    }
}
