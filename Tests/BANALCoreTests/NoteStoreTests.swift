import XCTest
@testable import BANALCore

@MainActor
final class NoteStoreTests: XCTestCase {
    func testCreateUpdateAndTrash() async throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let store = NoteStore(configuration: vault, monitor: nil, writeDebounceNanoseconds: 1_000_000)
        try store.open()
        XCTAssertFalse(store.notes.isEmpty, "bootstrap should create Welcome.md")

        let created = try store.createNote(title: "Groceries")
        XCTAssertTrue(FileManager.default.fileExists(atPath: created.fileURL.path))
        let source = try String(contentsOf: created.fileURL, encoding: .utf8)
        XCTAssertTrue(source.contains("title: Groceries"))
        XCTAssertTrue(source.contains("published: false"))

        var edited = created
        edited.body = "\nMilk and eggs\n"
        edited.tags = ["life"]
        store.update(edited, debounce: false)
        let reloaded = try NoteIO.load(url: created.fileURL, vaultURL: vault.rootURL)
        XCTAssertTrue(reloaded.body.contains("Milk and eggs"))
        XCTAssertEqual(reloaded.tags, ["life"])

        try store.trash(id: created.id)
        XCTAssertNil(store.note(id: created.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: created.fileURL.path))
    }

    func testExternalWriteIsPickedUpOnReload() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let url = vault.rootURL.appendingPathComponent("external.md")
        let now = Date()
        let document = FrontmatterCodec.serialize(
            frontmatter: Frontmatter(title: "From Vim", created: now, updated: now, tags: ["inbox"], published: false),
            body: "\nEdited outside the app.\n"
        )
        try Data(document.utf8).write(to: url)
        store.applyExternalChange(at: url)

        let note = try XCTUnwrap(store.note(id: "external.md"))
        XCTAssertEqual(note.title, "From Vim")
        XCTAssertTrue(note.body.contains("Edited outside the app."))
    }

    func testIdenticalUpdateDoesNotBumpUpdated() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let created = try store.createNote(title: "Stable")
        let before = created.updated
        store.update(created, debounce: false)
        let after = try XCTUnwrap(store.note(id: created.id))
        XCTAssertEqual(after.updated, before)
        let source = try String(contentsOf: created.fileURL, encoding: .utf8)
        XCTAssertTrue(source.contains("title: Stable"))
    }

    func testPublishedFilterAndSearch() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        var published = try store.createNote(title: "Public essay")
        published.published = true
        published.body = "\nA long published thought.\n"
        store.update(published, debounce: false)

        let draft = try store.createNote(title: "Private scratch")
        _ = draft

        XCTAssertEqual(store.notes(matching: .published).map(\.title), ["Public essay"])
        XCTAssertEqual(store.notes(matching: .all, query: "essay").map(\.title), ["Public essay"])
        XCTAssertTrue(store.notes(matching: .all, query: "scratch").contains(where: { $0.title == "Private scratch" }))
    }

    func testOpenMissingDirectoryDoesNotCreateIt() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "banal-gone-\(UUID().uuidString)",
            isDirectory: true
        )
        let store = NoteStore(configuration: VaultConfiguration(rootURL: url), monitor: nil)
        XCTAssertThrowsError(try store.open()) { error in
            XCTAssertEqual(error as? NoteStoreError, .vaultNotDirectory(url.standardizedFileURL))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertFalse(store.rootMissing)
    }

    func testApplyExternalChangeSetsRootMissingWhenVaultVanishes() throws {
        let vault = try makeVault()
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        XCTAssertFalse(store.rootMissing)
        XCTAssertFalse(store.notes.isEmpty)

        try FileManager.default.removeItem(at: vault.rootURL)
        store.applyExternalChange(at: vault.rootURL)

        XCTAssertTrue(store.rootMissing)
        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertTrue(store.folderTree.isEmpty)
    }

    func testWatchesExternalEditsFalseIgnoresNoteWrites() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        store.watchesExternalEdits = false
        try store.open()

        let url = vault.rootURL.appendingPathComponent("ignored.md")
        let now = Date()
        let document = FrontmatterCodec.serialize(
            frontmatter: Frontmatter(title: "Ignored", created: now, updated: now),
            body: "\nShould stay off the list.\n"
        )
        try Data(document.utf8).write(to: url)
        store.applyExternalChange(at: url)

        XCTAssertNil(store.note(id: "ignored.md"))
        XCTAssertFalse(store.rootMissing)
    }

    func testWatchesExternalEditsFalseStillSeesVanishedFolder() throws {
        let vault = try makeVault()
        let store = NoteStore(configuration: vault, monitor: nil)
        store.watchesExternalEdits = false
        try store.open()

        try FileManager.default.removeItem(at: vault.rootURL)
        store.applyExternalChange(at: vault.rootURL)

        XCTAssertTrue(store.rootMissing)
    }

    func testFilesystemMonitorObservesExternalCreate() async throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let store = NoteStore(configuration: vault, monitor: DirectoryMonitor(debounceInterval: 0.05), writeDebounceNanoseconds: 10_000_000)
        try store.open()

        let url = vault.rootURL.appendingPathComponent("watched.md")
        let now = Date()
        let document = FrontmatterCodec.serialize(
            frontmatter: Frontmatter(title: "Watched", created: now, updated: now),
            body: "\nFSEvents should see this.\n"
        )
        try Data(document.utf8).write(to: url)

        let deadline = Date().addingTimeInterval(3)
        while store.note(id: "watched.md") == nil, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let note = store.note(id: "watched.md")
        XCTAssertEqual(note?.title, "Watched", "FSEvents/NSFilePresenter should surface the new file (or the test timed out)")
    }

    // MARK: - Import (file associations, F-8)

    func testImportFileCopiesExternalNoteIntoVault() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("banal-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        let source = outside.appendingPathComponent("draft.md")
        let now = Date()
        let document = FrontmatterCodec.serialize(
            frontmatter: Frontmatter(title: "Draft", created: now, updated: now),
            body: "\nImported from outside.\n"
        )
        try Data(document.utf8).write(to: source)

        let imported = try store.importFile(from: source)

        XCTAssertEqual(imported.id, "draft.md")
        XCTAssertEqual(imported.title, "Draft")
        XCTAssertTrue(imported.body.contains("Imported from outside."))
        XCTAssertEqual(store.note(id: "draft.md")?.id, imported.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.fileURL.path), "file should be copied into the vault")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "the source file must be left untouched")
    }

    func testImportFileMakesUniqueNameOnCollision() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("banal-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        let source = outside.appendingPathComponent("draft.md")
        try Data("\nFirst copy\n".utf8).write(to: source)

        let first = try store.importFile(from: source)
        let second = try store.importFile(from: source)

        XCTAssertEqual(first.id, "draft.md")
        XCTAssertEqual(second.id, "draft-2.md")
        XCTAssertNotEqual(first.fileURL.path, second.fileURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.fileURL.path))
    }

    func testImportFileRejectsUnsupportedExtension() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("banal-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        let source = outside.appendingPathComponent("notes.txt")
        try Data("plain text".utf8).write(to: source)

        XCTAssertThrowsError(try store.importFile(from: source)) { error in
            XCTAssertEqual(error as? NoteStoreError, .unsupportedFileType("txt"))
        }
        XCTAssertNil(store.note(id: "notes.txt"), "nothing should be indexed")
    }

    func testImportFileRejectsFileInsideVault() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let inside = vault.rootURL.appendingPathComponent("already-here.md")
        try Data("\nInside the vault\n".utf8).write(to: inside)

        XCTAssertThrowsError(try store.importFile(from: inside)) { error in
            XCTAssertEqual(error as? NoteStoreError, .noteAlreadyInVault)
        }
    }

    func testImportFileIntoFolder() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("banal-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        let source = outside.appendingPathComponent("risotto.cook")
        try Data(CooklangStub.body.utf8).write(to: source)

        let imported = try store.importFile(from: source, folder: "Recipes")

        XCTAssertEqual(imported.id, "Recipes/risotto.cook")
        XCTAssertEqual(imported.language, .cooklang)
        XCTAssertTrue(store.folders.contains("Recipes"))
    }

    private func makeVault() throws -> VaultConfiguration {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-vault-\(UUID().uuidString)", isDirectory: true)
        let configuration = VaultConfiguration(rootURL: root)
        try VaultBootstrap.prepare(configuration)
        return configuration
    }
}
