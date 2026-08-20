import XCTest
@testable import BANALCore

final class FolderTreeTests: XCTestCase {
    func testBuildNestsAndKeepsEmptyLeaves() {
        let tree = FolderTree.build(paths: ["Essays/Drafts", "Inbox", "Essays"])
        XCTAssertEqual(tree.map(\.name), ["Essays", "Inbox"])
        XCTAssertEqual(tree[0].children.map(\.id), ["Essays/Drafts"])
        XCTAssertTrue(tree[1].children.isEmpty)
    }

    func testSanitizeRejectsReservedAndPathTricks() {
        XCTAssertNil(FolderName.sanitize("assets"))
        XCTAssertNil(FolderName.sanitize(".."))
        XCTAssertNil(FolderName.sanitize("a/b"))
        XCTAssertNil(FolderName.sanitize(".hidden"))
        XCTAssertEqual(FolderName.sanitize("  Essays  "), "Essays")
    }

    func testUniqueSiblingIncrements() {
        XCTAssertEqual(FolderName.uniqueSibling(base: "Inbox", existing: ["Inbox", "Inbox 2"]), "Inbox 3")
    }

    func testPathRemapAndContains() {
        XCTAssertTrue(FolderPath.contains("Essays/Drafts/wip", folder: "Essays"))
        XCTAssertTrue(FolderPath.contains("Essays", folder: "Essays"))
        XCTAssertFalse(FolderPath.contains("Essay", folder: "Essays"))
        XCTAssertEqual(FolderPath.remap("Essays/Drafts", from: "Essays", to: "Published"), "Published/Drafts")
        XCTAssertEqual(FolderPath.remap("Essays", from: "Essays", to: "Published"), "Published")
        XCTAssertNil(FolderPath.remap("Inbox/later", from: "Essays", to: "Published"))
    }
}

@MainActor
final class FolderStoreTests: XCTestCase {
    func testCreateNoteLandsInFolderAndEmptyFolderSurvives() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let folder = try store.createFolder(name: "Essays")
        XCTAssertTrue(store.folders.contains("Essays"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("Essays").path))

        let note = try store.createNote(title: "On folders", folder: folder.id)
        XCTAssertEqual(note.folder, "Essays")
        XCTAssertTrue(note.id.hasPrefix("Essays/"))
        XCTAssertEqual(store.notes(matching: .folder("Essays")).map(\.title), ["On folders"])
        XCTAssertFalse(store.notes(matching: .folder("Essays")).contains(where: { $0.title == "Welcome to BANAL" }))

        let empty = try store.createFolder(name: "Empty", parent: "Essays")
        XCTAssertTrue(store.folders.contains("Essays/Empty"))
        XCTAssertEqual(empty.id, "Essays/Empty")
    }

    func testRenameFolderMovesNotesOnDisk() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        _ = try store.createFolder(name: "Drafts")
        let note = try store.createNote(title: "WIP", folder: "Drafts")
        let renamed = try store.renameFolder(id: "Drafts", to: "Published")
        XCTAssertEqual(renamed.id, "Published")
        XCTAssertNil(store.note(id: note.id))
        let moved = try XCTUnwrap(store.notes.first { $0.title == "WIP" })
        XCTAssertEqual(moved.folder, "Published")
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.fileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: note.fileURL.path))
    }

    func testMoveNoteAndTrashFolder() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        _ = try store.createFolder(name: "A")
        _ = try store.createFolder(name: "B")
        let note = try store.createNote(title: "Traveling", folder: "A")
        let moved = try store.moveNote(id: note.id, toFolder: "B")
        XCTAssertEqual(moved.folder, "B")
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.fileURL.path))

        try store.trashFolder(id: "B")
        XCTAssertNil(store.note(id: moved.id))
        XCTAssertFalse(store.folders.contains("B"))
    }

    func testInboxLocationCreatesFolder() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        let note = try store.createNote(title: "Later", folder: "Inbox")
        XCTAssertEqual(note.folder, "Inbox")
        XCTAssertTrue(store.folders.contains("Inbox"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("Inbox", isDirectory: true).path))
    }

    func testReservedDirectoriesStayHidden() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        XCTAssertFalse(store.folders.contains("assets"))
        XCTAssertFalse(store.folders.contains(".banal"))
        XCTAssertFalse(store.folders.contains(".publish"))
    }

    func testExternalRenameRewritesNoteIds() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        _ = try store.createFolder(name: "Drafts")
        let note = try store.createNote(title: "WIP", folder: "Drafts")
        let source = vault.rootURL.appendingPathComponent("Drafts", isDirectory: true)
        let dest = vault.rootURL.appendingPathComponent("Published", isDirectory: true)
        try FileManager.default.moveItem(at: source, to: dest)
        store.applyExternalChange(at: dest)

        XCTAssertTrue(store.folders.contains("Published"))
        XCTAssertFalse(store.folders.contains("Drafts"))
        XCTAssertNil(store.note(id: note.id))
        let moved = try XCTUnwrap(store.notes.first { $0.title == "WIP" })
        XCTAssertEqual(moved.folder, "Published")
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.fileURL.path))
    }

    func testNestedCreateRenameAndTrashMatchDisk() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        _ = try store.createFolder(name: "Essays")
        _ = try store.createFolder(name: "Drafts", parent: "Essays")
        let note = try store.createNote(title: "On folders", folder: "Essays/Drafts")
        XCTAssertTrue(FileManager.default.fileExists(atPath: note.fileURL.path))

        let renamed = try store.renameFolder(id: "Essays/Drafts", to: "Published")
        XCTAssertEqual(renamed.id, "Essays/Published")
        XCTAssertNil(store.note(id: note.id))
        let moved = try XCTUnwrap(store.notes.first { $0.title == "On folders" })
        XCTAssertEqual(moved.folder, "Essays/Published")
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.fileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: note.fileURL.path))

        try store.trashFolder(id: "Essays")
        XCTAssertFalse(store.folders.contains("Essays"))
        XCTAssertFalse(store.folders.contains("Essays/Published"))
        XCTAssertNil(store.note(id: moved.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("Essays").path))
    }

    func testExternalMkdirAppearsInTree() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        let url = vault.rootURL.appendingPathComponent("FromFinder", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        store.applyExternalChange(at: url)
        XCTAssertTrue(store.folders.contains("FromFinder"))
    }

    func testPreferencesRoundTripAndNewNoteLocation() {
        let defaults = UserDefaults(suiteName: "banal.tests.\(UUID().uuidString)")!
        var prefs = AppPreferences(sort: .title, newNoteLocation: .inbox, fontSize: 18)
        AppPreferencesStore.save(prefs, defaults: defaults)
        let loaded = AppPreferencesStore.load(defaults: defaults)
        XCTAssertEqual(loaded.sort, .title)
        XCTAssertEqual(loaded.newNoteLocation, .inbox)
        XCTAssertEqual(loaded.fontSize, 18)
        XCTAssertEqual(prefs.folderForNewNote(selected: .all), "Inbox")
        XCTAssertEqual(prefs.folderForNewNote(selected: .folder("Essays")), "Inbox")
        prefs.newNoteLocation = .selectedFolder
        XCTAssertEqual(prefs.folderForNewNote(selected: .folder("Essays")), "Essays")
        XCTAssertNil(prefs.folderForNewNote(selected: .all))
    }

    func testDefaultTypePreferencesAndLineHeight() {
        let defaults = AppPreferences.default
        XCTAssertEqual(defaults.fontSize, 16)
        XCTAssertEqual(defaults.lineHeight, .normal)
        XCTAssertTrue(defaults.limitLineLength)
        XCTAssertEqual(LineHeightSetting.tight.multiplier, 1.35)
        XCTAssertEqual(LineHeightSetting.normal.multiplier, 1.5)
        XCTAssertEqual(LineHeightSetting.loose.multiplier, 1.7)
    }

    private func makeVault() throws -> VaultConfiguration {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-folders-\(UUID().uuidString)", isDirectory: true)
        let configuration = VaultConfiguration(rootURL: root)
        try VaultBootstrap.prepare(configuration)
        return configuration
    }
}
