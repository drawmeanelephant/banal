import BANALAppModel
import BANALCore
import XCTest

@MainActor
final class ImportControllerTests: XCTestCase {
    func testOpenInsideVaultSelectsExistingNote() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        let note = try store.createNote(title: "Alpha")

        let controller = ImportController()
        let decision = controller.openExternalNote(
            at: note.fileURL,
            vaultRoot: vault.rootURL,
            needsVault: false,
            importer: { try store.importFile(from: $0) },
            noteExists: { store.note(id: $0) != nil }
        )
        XCTAssertEqual(decision, .selectExisting(id: note.id))
    }

    func testOpenInsideVaultNonNoteFileIsNotANote() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let stray = vault.rootURL.appendingPathComponent("data.json")
        try Data("{}".utf8).write(to: stray)

        let controller = ImportController()
        let decision = controller.openExternalNote(
            at: stray,
            vaultRoot: vault.rootURL,
            needsVault: false,
            importer: { try store.importFile(from: $0) },
            noteExists: { store.note(id: $0) != nil }
        )
        XCTAssertEqual(decision, .notANote)
    }

    func testOpenOutsideVaultImportsAndDeduplicatesTheSameAction() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("banal-open-\(UUID().uuidString).md")
        try Data("# Risotto\n".utf8).write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }

        let controller = ImportController()
        let first = controller.openExternalNote(
            at: outside,
            vaultRoot: vault.rootURL,
            needsVault: false,
            importer: { try store.importFile(from: $0) },
            noteExists: { store.note(id: $0) != nil }
        )
        guard case .imported(let id) = first else {
            return XCTFail("expected an import, got \(first)")
        }
        XCTAssertNotNil(store.note(id: id), "the copy lives in the vault")

        // `.onOpenURL` and the delegate's openFiles both fire for one
        // user action — the second delivery must not import twice.
        let second = controller.openExternalNote(
            at: outside,
            vaultRoot: vault.rootURL,
            needsVault: false,
            importer: { try store.importFile(from: $0) },
            noteExists: { store.note(id: $0) != nil }
        )
        XCTAssertEqual(second, .queued, "duplicate delivery is swallowed")
    }

    func testNoVaultQueuesThenDrainsOnBootstrap() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("banal-queued-\(UUID().uuidString).md")
        try Data("# Queued\n".utf8).write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }

        let store = NoteStore(configuration: vault, monitor: nil)
        let controller = ImportController()

        let queued = controller.openExternalNote(
            at: outside,
            vaultRoot: vault.rootURL,
            needsVault: true,
            importer: { try store.importFile(from: $0) },
            noteExists: { store.note(id: $0) != nil }
        )
        XCTAssertEqual(queued, .queued)

        try store.open()
        let drained = controller.drainPendingImports(
            vaultRoot: vault.rootURL,
            importer: { try store.importFile(from: $0) },
            noteExists: { store.note(id: $0) != nil }
        )
        XCTAssertEqual(drained.count, 1)
        guard case .imported(let id) = drained.first?.decision else {
            return XCTFail("expected the queued file to import")
        }
        XCTAssertTrue(store.notes.contains { $0.id == id })
    }

    func testServiceNoteInfersTitleAndHonorsDestination() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let controller = ImportController()

        XCTAssertEqual(controller.createServiceNote(text: "   \n ", store: store, destinationFolder: nil), .emptyText)

        let outcome = controller.createServiceNote(
            text: "Sourdough starter notes\n\nFeed it daily.",
            store: store,
            destinationFolder: nil
        )
        guard case .created(let note, _) = outcome else {
            return XCTFail("expected a created note, got \(outcome)")
        }
        XCTAssertEqual(note.title, "Sourdough starter notes")
        XCTAssertTrue(store.notes.contains { $0.id == note.id })

        let folderOutcome = controller.createServiceNote(text: "In a folder", store: store, destinationFolder: "Inbox")
        guard case .created(let filed, let destination) = folderOutcome else {
            return XCTFail("expected a created note, got \(folderOutcome)")
        }
        XCTAssertEqual(destination, "Inbox")
        XCTAssertEqual(filed.id, "Inbox/In a folder.md")
    }
}
