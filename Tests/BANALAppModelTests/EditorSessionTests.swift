 @testable import BANALAppModel
import BANALCore
import Combine
import XCTest

@MainActor
final class EditorSessionTests: XCTestCase {
    func testLoadPopulatesBufferAndResetsGuard() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        let note = try store.createNote(title: "Alpha", body: "Body text")

        let session = EditorSession()
        session.selectedText = "leftover"
        session.load(from: note, selectedID: note.id)

        XCTAssertEqual(session.editorTitle, "Alpha")
        XCTAssertEqual(session.editorText, "Body text")
        XCTAssertEqual(session.editorTags, "")
        XCTAssertFalse(session.editorPublished)
        XCTAssertFalse(session.isDirty)
        XCTAssertEqual(session.selectedText, "")
        XCTAssertEqual(session.loadedFingerprint, note.contentFingerprint)
    }

    func testApplyChangesReturnsParsedChangeAndBodyFlag() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        var note = try store.createNote(title: "Alpha")
        let session = EditorSession()
        session.load(from: note, selectedID: note.id)
        session.editorTitle = "Renamed"
        session.editorTags = " a , b ,, "
        session.editorPublished = true

        let change = try XCTUnwrap(session.applyChanges(to: note, selectedID: note.id))
        XCTAssertFalse(change.bodyChanged, "only title/tags/published changed")
        XCTAssertEqual(change.updated.title, "Renamed")
        XCTAssertEqual(change.updated.tags, ["a", "b"])
        XCTAssertTrue(change.updated.published)
        XCTAssertTrue(session.isDirty)

        session.editorText = "\nRewritten."
        let bodyChange = try XCTUnwrap(session.applyChanges(to: note, selectedID: note.id))
        XCTAssertTrue(bodyChange.bodyChanged)
    }

    func testApplyChangesIgnoresEchoesFromOtherSessions() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        let note = try store.createNote(title: "Alpha")
        var mutated = note
        mutated.title = "Elsewhere"

        let session = EditorSession()
        session.load(from: note, selectedID: note.id)

        // A write loaded for another selection must not land (F-9).
        let staleSelection = session.applyChanges(to: mutated, selectedID: "other-note")
        XCTAssertNil(staleSelection)

        // An identical buffer is not a change at all.
        let identical = session.applyChanges(to: note, selectedID: note.id)
        XCTAssertNil(identical)
    }

    func testPersistWritesThroughAndFollowsRetitleToNewFileID() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        let note = try store.createNote(title: "Alpha", body: "First.")

        let session = EditorSession()
        session.load(from: note, selectedID: note.id)
        session.editorTitle = "Beta"
        session.editorText = "\nRewritten."
        _ = session.applyChanges(to: note, selectedID: note.id)

        let renamedID = session.persist(to: note.id, store: store, writingToolsActive: false)

        XCTAssertEqual(renamedID, "Beta.md", "plain names: the file follows the retitled note")
        XCTAssertNil(store.note(id: "Alpha.md"), "the old id is gone")
        XCTAssertEqual(store.note(id: renamedID ?? "")?.body, "\nRewritten.")
        XCTAssertFalse(session.isDirty, "the guard settles after persisting")
        XCTAssertEqual(session.loadedForID, renamedID)
    }

    func testPersistDoesNothingWhenClean() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        var note = try store.createNote(title: "Alpha")
        let session = EditorSession()
        session.load(from: note, selectedID: note.id)
        session.editorTitle = "Unsaved"

        let result = session.persist(to: note.id, store: store, writingToolsActive: false)
        XCTAssertNil(result)
        XCTAssertEqual(store.note(id: note.id)?.title, "Alpha", "a clean buffer never writes")
    }

    func testBufferMatchesDiskDrivesIgnoreReconciliation() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        var note = try store.createNote(title: "Alpha")
        note.tags = ["x"]
        store.update(note, debounce: false)

        let session = EditorSession()
        session.load(from: note, selectedID: note.id)
        let disk = try XCTUnwrap(store.note(id: note.id))
        XCTAssertTrue(session.bufferMatchesDisk(disk), "a freshly loaded buffer matches its note")

        session.editorText = "\nEdited."
        _ = session.applyChanges(to: disk, selectedID: note.id)
        XCTAssertFalse(session.bufferMatchesDisk(disk))

        session.acceptIgnoredExternalState(disk)
        XCTAssertEqual(session.loadedFingerprint, disk.contentFingerprint, "the guard adopts the disk state it accepted")
        XCTAssertTrue(session.isDirty, "the buffer still differs from disk")
    }

    func testDiskChangeWarningFiresOncePerFingerprint() {
        let session = EditorSession()
        XCTAssertTrue(session.markDiskChangeWarning(fingerprint: "f1"))
        XCTAssertFalse(session.markDiskChangeWarning(fingerprint: "f1"))
        XCTAssertTrue(session.markDiskChangeWarning(fingerprint: "f2"))
    }

    func testInsertAtCaretPrefersHandlerThenSplicesWithCaretMath() {
        let session = EditorSession()
        session.editorText = "Hello world"
        session.selectedRange = NSRange(location: 5, length: 1)

        var claimed: [String] = []
        session.insertAtCaretHandler = { text in
            claimed.append(text)
            return true
        }
        session.insertTextAtCaret(",!")
        XCTAssertEqual(claimed, [",!"])
        XCTAssertEqual(session.editorText, "Hello world", "handler claims the edit; buffer untouched")

        session.insertAtCaretHandler = nil
        session.insertTextAtCaret(" there ")
        XCTAssertEqual(session.editorText, "Hello there world")
        XCTAssertEqual(session.selectedText, "")
    }

    func testInsertIntoEditorAppendsWhenRangeIsStale() {
        let session = EditorSession()
        session.editorText = "Ends here"
        session.selectedRange = NSRange(location: 500, length: 3)

        session.insertTextIntoEditor(" now")
        XCTAssertEqual(session.editorText, "Ends here now")
        XCTAssertEqual(session.selectedRange.location, ("Ends here" as NSString).length + 4)
    }
}
