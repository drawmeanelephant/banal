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

    /// F-9 belt-and-braces: a re-persist whose persisted fields are
    /// identical must not touch the file, even when the caller's note
    /// carries a different `updated` (the stale-buffer-echo shape).
    func testUpdateWithStaleUpdatedButIdenticalFieldsIsNoop() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let created = try store.createNote(title: "Stable")
        let bytesBefore = try Data(contentsOf: created.fileURL)

        var stale = created
        stale.updated = Date().addingTimeInterval(3600)
        store.update(stale, debounce: false)

        let after = try XCTUnwrap(store.note(id: created.id))
        XCTAssertEqual(after.updated, created.updated, "updated must not move for a no-op write")
        let bytesAfter = try Data(contentsOf: created.fileURL)
        XCTAssertEqual(bytesAfter, bytesBefore, "the file must be byte-identical")
    }

    /// Positive control: a real content change still bumps `updated` and
    /// persists — the guard must not be so strict it swallows edits.
    func testUpdateWithRealChangeBumpsUpdatedAndPersists() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let created = try store.createNote(title: "Editing")
        var edited = created
        edited.body = "\nNew words.\n"
        edited.updated = created.updated
        store.update(edited, debounce: false)

        let after = try XCTUnwrap(store.note(id: created.id))
        XCTAssertTrue(after.updated > created.updated, "a real edit must move updated forward")
        XCTAssertEqual(after.body, "\nNew words.\n")
        let reloaded = try NoteIO.load(url: created.fileURL, vaultURL: vault.rootURL)
        XCTAssertEqual(reloaded.body, "\nNew words.\n")
        XCTAssertLessThan(
            abs(reloaded.updated.timeIntervalSince(after.updated)),
            1.0,
            "disk must carry the bumped updated (frontmatter keeps second precision)"
        )
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
        // K-1 plain names: collisions number Finder-style, not with dashes.
        XCTAssertEqual(second.id, "draft 2.md")
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

    // MARK: - Plain names (K-1, #192)

    /// A new note is born as `<Title>.<ext>` — no date prefix, case and
    /// accents preserved.
    func testCreateUsesPlainNames() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let created = try store.createNote(title: "Risotto alla Milanese")
        XCTAssertEqual(created.id, "Risotto alla Milanese.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: created.fileURL.path))
    }

    /// Collisions number up the way Finder does: `Risotto.md`,
    /// `Risotto 2.md`, `Risotto 3.md`.
    func testPlainNameCollisionsNumberFinderStyle() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        _ = try store.createNote(title: "Risotto")
        let second = try store.createNote(title: "Risotto")
        let third = try store.createNote(title: "Risotto")
        XCTAssertEqual(second.id, "Risotto 2.md")
        XCTAssertEqual(third.id, "Risotto 3.md")
    }

    /// Titles that cannot be a path component are made safe, not
    /// mangled into slugs. An empty (or separator-only) title falls
    /// back to `Untitled`.
    func testUnsafeTitlesAreSanitizedNotSlugified() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let slashes = try store.createNote(title: "A/B: C")
        XCTAssertEqual(slashes.id, "A-B- C.md")

        let hidden = try store.createNote(title: ".hidden note")
        XCTAssertEqual(hidden.id, "hidden note.md")

        let untitled = try store.createNote(title: "   ")
        XCTAssertEqual(untitled.id, "Untitled.md")
    }

    /// Plain names work through folders too.
    func testCreateInFolderUsesPlainNameInsideFolder() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let created = try store.createNote(title: "Sunday Sauce", folder: "Recipes")
        XCTAssertEqual(created.id, "Recipes/Sunday Sauce.md")
    }

    /// Retitling a plain-named file renames it on disk; id and file URL
    /// move together and the content rides along byte-for-byte.
    func testRenameFollowsTitleWhenFileMatchesTitle() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let created = try store.createNote(title: "Risotto", body: "\nArborio.\n")
        var edited = created
        edited.title = "Paella"
        store.update(edited, debounce: false)

        let renamed = try XCTUnwrap(
            try store.renameNote(id: created.id, previousTitle: "Risotto", to: "Paella")
        )
        XCTAssertEqual(renamed.id, "Paella.md")
        XCTAssertFalse(FileManager.default.fileExists(atPath: created.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamed.fileURL.path))

        let reloaded = try NoteIO.load(url: renamed.fileURL, vaultURL: vault.rootURL)
        XCTAssertEqual(reloaded.title, "Paella")
        XCTAssertTrue(reloaded.body.contains("Arborio."))
        XCTAssertNotNil(store.note(id: "Paella.md"))
        XCTAssertNil(store.note(id: created.id))
    }

    /// Legacy date-stamped files never migrate behind the user's back:
    /// their leaf does not match the title, so retitle leaves them be.
    func testRenameSkipsLegacyDateStampedFiles() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let now = Date()
        let document = FrontmatterCodec.serialize(
            frontmatter: Frontmatter(title: "Risotto", created: now, updated: now, tags: [], published: false),
            body: "\nOld habit.\n"
        )
        let url = vault.rootURL.appendingPathComponent("2026-08-25-risotto.md")
        try Data(document.utf8).write(to: url)
        store.applyExternalChange(at: url)

        var edited = try XCTUnwrap(store.note(id: "2026-08-25-risotto.md"))
        edited.title = "Paella"
        store.update(edited, debounce: false)

        let renamed = try store.renameNote(
            id: "2026-08-25-risotto.md",
            previousTitle: "Risotto",
            to: "Paella"
        )
        XCTAssertNil(renamed, "a date-stamped file must not follow its title")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    /// A difference only in case, accents, or folded separators is not
    /// worth a rename — no churn. Empty titles never rename either.
    func testRenameIgnoresSanitizationOnlyDifferences() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let created = try store.createNote(title: "Risotto")
        XCTAssertNil(try store.renameNote(id: created.id, previousTitle: "Risotto", to: "RISOTTO"))
        XCTAssertNil(try store.renameNote(id: created.id, previousTitle: "Risotto", to: "Risotto:"))
        XCTAssertNil(try store.renameNote(id: created.id, previousTitle: "Risotto", to: ""))
        XCTAssertNil(try store.renameNote(id: created.id, previousTitle: "", to: "Paella"))
        XCTAssertEqual(store.note(id: created.id)?.id, "Risotto.md")
    }

    /// Renaming onto an existing name numbers up instead of clobbering.
    func testRenameNumbersOnCollision() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        _ = try store.createNote(title: "Paella", body: "\nAlready here.\n")
        let risotto = try store.createNote(title: "Risotto")

        let renamed = try XCTUnwrap(
            try store.renameNote(id: risotto.id, previousTitle: "Risotto", to: "Paella")
        )
        XCTAssertEqual(renamed.id, "Paella 2.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamed.fileURL.path))
    }
}
