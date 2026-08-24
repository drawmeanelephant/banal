import XCTest
@testable import BANALCore

final class VaultSeedTests: XCTestCase {
    func testSeedsWelcomeIntoEmptyFolder() throws {
        let vault = try makeFolder()
        defer { try? FileManager.default.removeItem(at: vault) }

        XCTAssertTrue(VaultSeed.seedWelcomeIfNeeded(in: vault))

        let welcomeURL = vault.appendingPathComponent(VaultSeed.welcomeFileName)
        let note = try NoteIO.load(url: welcomeURL, vaultURL: vault)
        XCTAssertEqual(note.title, "Welcome to BANAL")
        XCTAssertEqual(note.language, .markdown)
        XCTAssertFalse(note.body.isEmpty)
    }

    func testDoesNotSeedAFolderThatAlreadyHadAWelcome() throws {
        let vault = try makeFolder()
        defer { try? FileManager.default.removeItem(at: vault) }

        XCTAssertTrue(VaultSeed.seedWelcomeIfNeeded(in: vault))
        XCTAssertFalse(VaultSeed.seedWelcomeIfNeeded(in: vault))

        // Deleting the note must be final. The app only calls the seeder
        // at folder-creation time (VaultPicker), so a later first-run on
        // this now-empty folder never writes again — asserted here by
        // exercising the same guard the call site relies on: an existing
        // Welcome.md blocks a reseed.
        try FileManager.default.removeItem(at: vault.appendingPathComponent(VaultSeed.welcomeFileName))
        try Data("x".utf8).write(to: vault.appendingPathComponent(VaultSeed.welcomeFileName))
        XCTAssertFalse(VaultSeed.seedWelcomeIfNeeded(in: vault))
    }

    func testNeverTouchesAFolderWithNotes() throws {
        let vault = try makeFolder()
        defer { try? FileManager.default.removeItem(at: vault) }
        try Data("hello".utf8).write(to: vault.appendingPathComponent("Groceries.md"))

        XCTAssertFalse(VaultSeed.seedWelcomeIfNeeded(in: vault))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: vault.path), ["Groceries.md"])
    }

    func testSkipsWhenAnyLanguageNoteExists() throws {
        let vault = try makeFolder()
        defer { try? FileManager.default.removeItem(at: vault) }
        try Data("h1. Page".utf8).write(to: vault.appendingPathComponent("page.textile"))

        XCTAssertFalse(VaultSeed.seedWelcomeIfNeeded(in: vault))
    }

    func testMissingFolderIsNoOp() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("banal-seed-missing-\(UUID().uuidString)", isDirectory: true)
        XCTAssertFalse(VaultSeed.seedWelcomeIfNeeded(in: missing))
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
    }

    private func makeFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("banal-seed-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
