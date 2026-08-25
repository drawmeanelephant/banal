import BANALAppModel
import BANALCore
import XCTest

@MainActor
final class FolderControllerTests: XCTestCase {
    func testNewFolderFlowClearsDraftAndCreatesDirectory() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let controller = FolderController()
        controller.beginNewFolder(defaultName: "Recipes")
        XCTAssertTrue(controller.isCreating)
        XCTAssertEqual(controller.nameDraft, "Recipes")

        let created = try controller.confirmNewFolder(store: store, parent: nil)
        XCTAssertFalse(controller.isCreating)
        XCTAssertEqual(created.id, "Recipes")
        XCTAssertEqual(controller.nameDraft, "")
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("Recipes").path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue, "a folder is a directory")
    }

    func testRenameFlowReturnsPreviousIDForSelectionRemap() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        _ = try store.createFolder(name: "Alpha")

        let controller = FolderController()
        controller.beginRename("Alpha")
        XCTAssertTrue(controller.isRenaming)
        XCTAssertEqual(controller.nameDraft, "Alpha", "the draft starts from the leaf name")

        controller.nameDraft = "Gamma"
        let result = try XCTUnwrap(controller.confirmRename(store: store))
        XCTAssertEqual(result.previousID, "Alpha")
        XCTAssertEqual(result.renamed.id, "Gamma")
        XCTAssertFalse(controller.isRenaming)
        XCTAssertNil(controller.renamingID)
    }

    func testConfirmRenameWithoutInFlightRenameIsNil() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let controller = FolderController()
        let result = try controller.confirmRename(store: store)
        XCTAssertNil(result)
    }

    // MARK: - Drop resolution

    func testMoveTargetResolvesByIDThenPathForms() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        let note = try store.createNote(title: "Alpha", folder: "Things")

        XCTAssertEqual(FolderController.resolvedMoveTarget(for: note.id, notes: store.notes), note.id)

        let path = note.fileURL.path
        XCTAssertEqual(FolderController.resolvedMoveTarget(for: path, notes: store.notes), note.id)

        let urlForm = note.fileURL.absoluteString
        XCTAssertEqual(FolderController.resolvedMoveTarget(for: urlForm, notes: store.notes), note.id)

        XCTAssertEqual(
            FolderController.resolvedMoveTarget(for: "not-anywhere", notes: store.notes),
            "not-anywhere",
            "unknown identifiers pass through for the store to report"
        )
    }

    func testMoveTargetFromDroppedFileURLPrefersNoteThenVaultRelative() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        let note = try store.createNote(title: "Alpha", folder: "Things")

        XCTAssertEqual(
            FolderController.resolvedMoveTarget(for: note.fileURL, vaultRoot: vault.rootURL, notes: store.notes),
            note.id
        )

        let externalInVault = vault.rootURL.appendingPathComponent("Stray.md")
        try Data("# Stray\n".utf8).write(to: externalInVault)
        XCTAssertEqual(
            FolderController.resolvedMoveTarget(for: externalInVault, vaultRoot: vault.rootURL, notes: store.notes),
            "Stray.md"
        )

        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("outside-\(UUID().uuidString).md")
        try Data("x".utf8).write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        XCTAssertEqual(
            FolderController.resolvedMoveTarget(for: outside, vaultRoot: vault.rootURL, notes: store.notes),
            outside.path
        )
    }
}
