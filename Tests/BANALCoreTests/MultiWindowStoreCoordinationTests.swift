import XCTest
@testable import BANALCore

@MainActor
final class MultiWindowStoreCoordinationTests: XCTestCase {
    func testMultiModelObservationOnSameNoteStore() async throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let store = NoteStore(configuration: vault, monitor: nil, writeDebounceNanoseconds: 1_000_000)
        try store.open()

        let noteA = try store.createNote(title: "Note A")
        let noteB = try store.createNote(title: "Note B")

        // Simulate Window 1 and Window 2 observing the same store
        var window1NotesCount = store.notes.count
        var window2NotesCount = store.notes.count

        XCTAssertEqual(window1NotesCount, 3) // Welcome.md + Note A + Note B
        XCTAssertEqual(window2NotesCount, 3)

        // Window 1 edits Note A
        var editedA = noteA
        editedA.body = "\nUpdated from Window 1\n"
        store.update(editedA, debounce: false)

        // Verify store reflects update
        let fetchedA = try XCTUnwrap(store.note(id: noteA.id))
        XCTAssertEqual(fetchedA.body, "\nUpdated from Window 1\n")

        // Window 2 creates Note C
        let noteC = try store.createNote(title: "Note C")
        window1NotesCount = store.notes.count
        window2NotesCount = store.notes.count

        XCTAssertEqual(window1NotesCount, 4)
        XCTAssertEqual(window2NotesCount, 4)
        XCTAssertNotNil(store.note(id: noteC.id))

        // Window 1 moves Note B to a folder
        let movedB = try store.moveNote(id: noteB.id, toFolder: "Archive")
        XCTAssertEqual(movedB.folder, "Archive")
        XCTAssertEqual(store.note(id: movedB.id)?.folder, "Archive")
    }

    private func makeVault() throws -> VaultConfiguration {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return VaultConfiguration(rootURL: tempDir)
    }
}
