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

    private func makeVault() throws -> VaultConfiguration {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-vault-\(UUID().uuidString)", isDirectory: true)
        let configuration = VaultConfiguration(rootURL: root)
        try VaultBootstrap.prepare(configuration)
        return configuration
    }
}
