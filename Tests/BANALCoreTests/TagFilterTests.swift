import XCTest
@testable import BANALCore

@MainActor
final class TagFilterTests: XCTestCase {
    func testUniqueTagCollectionAndSorting() async throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let store = NoteStore(configuration: vault, monitor: nil, writeDebounceNanoseconds: 1_000_000)
        try store.open()
        for note in store.notes {
            try store.trash(id: note.id)
        }

        let note1 = try store.createNote(title: "Note 1")
        var edited1 = note1
        edited1.tags = ["zebra", "draft"]
        store.update(edited1, debounce: false)

        let note2 = try store.createNote(title: "Note 2")
        var edited2 = note2
        edited2.tags = ["draft", "apple"]
        store.update(edited2, debounce: false)

        let tags = store.tags
        XCTAssertEqual(tags, ["apple", "draft", "zebra"])
    }

    func testNotesMatchingTagFilter() async throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let store = NoteStore(configuration: vault, monitor: nil, writeDebounceNanoseconds: 1_000_000)
        try store.open()

        let note1 = try store.createNote(title: "Draft Note")
        var edited1 = note1
        edited1.tags = ["draft"]
        store.update(edited1, debounce: false)

        let note2 = try store.createNote(title: "Recipe Note")
        var edited2 = note2
        edited2.tags = ["recipe"]
        store.update(edited2, debounce: false)

        let draftNotes = store.notes(matching: .tag("draft"))
        XCTAssertEqual(draftNotes.count, 1)
        XCTAssertEqual(draftNotes.first?.displayTitle, "Draft Note")

        let recipeNotes = store.notes(matching: .tag("recipe"))
        XCTAssertEqual(recipeNotes.count, 1)
        XCTAssertEqual(recipeNotes.first?.displayTitle, "Recipe Note")

        let allNotes = store.notes(matching: .all)
        XCTAssertGreaterThanOrEqual(allNotes.count, 2)
    }

    func testEmptyTagMatchesNone() async throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let store = NoteStore(configuration: vault, monitor: nil, writeDebounceNanoseconds: 1_000_000)
        try store.open()

        let empty = store.notes(matching: .tag("nonexistent"))
        XCTAssertTrue(empty.isEmpty)
    }

    private func makeVault() throws -> VaultConfiguration {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return VaultConfiguration(rootURL: tempDir)
    }
}
