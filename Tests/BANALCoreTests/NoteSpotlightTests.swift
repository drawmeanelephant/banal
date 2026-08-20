@testable import BANALCore
import CoreSpotlight
import Foundation
import UniformTypeIdentifiers
import XCTest

final class MockSpotlightIndex: SpotlightSearchIndex, @unchecked Sendable {
    var indexedItems: [CSSearchableItem] = []
    var deletedIDs: [String] = []
    var deletedDomains: [String] = []

    func indexSearchableItems(_ items: [CSSearchableItem]) async throws {
        indexedItems.append(contentsOf: items)
    }

    func deleteSearchableItems(withIdentifiers identifiers: [String]) async throws {
        deletedIDs.append(contentsOf: identifiers)
    }

    func deleteSearchableItems(withDomainIdentifiers domainIdentifiers: [String]) async throws {
        deletedDomains.append(contentsOf: domainIdentifiers)
    }

    func deleteAllSearchableItems() async throws {
        deletedDomains.append("all")
    }
}

final class MockNoteSpotlightIndexer: NoteSpotlightIndexing, @unchecked Sendable {
    var indexedNotes: [Note] = []
    var deindexedIDs: [String] = []
    var reindexedNotes: [Note] = []

    func index(notes: [Note], vaultName: String?, ingredients: [String: [String]]) {
        indexedNotes.append(contentsOf: notes)
    }

    func deindex(ids: [String]) {
        deindexedIDs.append(contentsOf: ids)
    }

    func reindexAll(notes: [Note], vaultName: String?, ingredients: [String: [String]]) {
        reindexedNotes = notes
    }
}

@MainActor
final class NoteSpotlightTests: XCTestCase {
    private func makeVault() throws -> VaultConfiguration {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("banal-spotlight-test-\(UUID().uuidString)", isDirectory: true)
        let config = VaultConfiguration(rootURL: root)
        try VaultBootstrap.prepare(config)
        return config
    }

    func testMarkdownNoteAttributeSet() {
        let note = Note(
            id: "Projects/Tucson.md",
            fileURL: URL(fileURLWithPath: "/tmp/vault/Projects/Tucson.md"),
            title: "Tucson Planning",
            body: "# Tucson Planning\n\nDiscuss roadmap and system search features for BANAL.",
            created: Date(timeIntervalSince1970: 1000),
            updated: Date(timeIntervalSince1970: 2000),
            tags: ["roadmap", "m10"],
            published: true,
            modifiedAt: Date(timeIntervalSince1970: 2000)
        )

        let item = NoteSpotlightItem.makeItem(for: note, vaultName: "MyVault")
        XCTAssertEqual(item.uniqueIdentifier, "Projects/Tucson.md")
        XCTAssertEqual(item.domainIdentifier, NoteSpotlightIndexer.domainIdentifier)

        let attrs = item.attributeSet
        XCTAssertEqual(attrs.title, "Tucson Planning")
        XCTAssertEqual(attrs.containerTitle, "Projects")
        XCTAssertEqual(attrs.contentModificationDate, Date(timeIntervalSince1970: 2000))
        XCTAssertEqual(attrs.contentDescription, note.snippet)
        XCTAssertEqual(attrs.textContent, note.body)

        let keywords = attrs.keywords ?? []
        XCTAssertTrue(keywords.contains("roadmap"))
        XCTAssertTrue(keywords.contains("m10"))
        XCTAssertTrue(keywords.contains("markdown"))
        XCTAssertTrue(keywords.contains("md"))
    }

    func testCooklangRecipeAttributeSetIncludesIngredients() {
        let note = Note(
            id: "Recipes/Risotto.cook",
            fileURL: URL(fileURLWithPath: "/tmp/vault/Recipes/Risotto.cook"),
            title: "Risotto Milanese",
            body: ">> servings: 4\nMelt @butter{2%tbsp} in saucepan. Add @arborio rice{1%cup} and pinch of @saffron{1%pinch}.",
            created: Date(timeIntervalSince1970: 1000),
            updated: Date(timeIntervalSince1970: 2000),
            tags: ["dinner", "italian"],
            published: false,
            modifiedAt: Date(timeIntervalSince1970: 2000)
        )

        let item = NoteSpotlightItem.makeItem(for: note, vaultName: "MyVault")
        let attrs = item.attributeSet
        XCTAssertEqual(attrs.title, "Risotto Milanese")
        XCTAssertEqual(attrs.containerTitle, "Recipes")

        let keywords = attrs.keywords ?? []
        XCTAssertTrue(keywords.contains("dinner"))
        XCTAssertTrue(keywords.contains("italian"))
        XCTAssertTrue(keywords.contains("cooklang"))
        XCTAssertTrue(keywords.contains("cook"))
        XCTAssertTrue(keywords.contains("butter"))
        XCTAssertTrue(keywords.contains("arborio rice"))
        XCTAssertTrue(keywords.contains("saffron"))
    }

    func testTextileNoteAttributeSet() {
        let note = Note(
            id: "Notes/Welcome.textile",
            fileURL: URL(fileURLWithPath: "/tmp/vault/Notes/Welcome.textile"),
            title: "Welcome Textile",
            body: "h1. Welcome to Textile\n\nThis is a simple textile document.",
            created: Date(timeIntervalSince1970: 1000),
            updated: Date(timeIntervalSince1970: 2000),
            tags: ["intro"],
            published: false,
            modifiedAt: Date(timeIntervalSince1970: 2000)
        )

        let item = NoteSpotlightItem.makeItem(for: note, vaultName: "MyVault")
        let attrs = item.attributeSet
        XCTAssertEqual(attrs.title, "Welcome Textile")
        XCTAssertEqual(attrs.containerTitle, "Notes")
        let keywords = attrs.keywords ?? []
        XCTAssertTrue(keywords.contains("intro"))
        XCTAssertTrue(keywords.contains("textile"))
    }

    func testNoteEntityAttributeSet() {
        let note = Note(
            id: "Ideas/macOS.md",
            fileURL: URL(fileURLWithPath: "/tmp/vault/Ideas/macOS.md"),
            title: "Mac App Ideas",
            body: "Design thoughts",
            created: Date(),
            updated: Date(),
            tags: [],
            published: false,
            modifiedAt: Date()
        )

        let entity = NoteEntity(from: note)
        XCTAssertEqual(entity.id, "Ideas/macOS.md")
        XCTAssertEqual(entity.title, "Mac App Ideas")
        XCTAssertEqual(entity.folder, "Ideas")
        XCTAssertEqual(entity.attributeSet.title, "Mac App Ideas")
        XCTAssertEqual(entity.attributeSet.containerTitle, "Ideas")
        XCTAssertTrue(entity.attributeSet.keywords?.contains("markdown") ?? false)
    }

    func testSpotlightIndexerOperations() async throws {
        let mockIndex = MockSpotlightIndex()
        let indexer = NoteSpotlightIndexer(index: mockIndex, domainIdentifier: "test.banal.notes")

        let note1 = Note(
            id: "n1.md",
            fileURL: URL(fileURLWithPath: "/tmp/vault/n1.md"),
            title: "Note 1",
            body: "Body 1",
            created: Date(),
            updated: Date(),
            modifiedAt: Date()
        )
        let note2 = Note(
            id: "n2.md",
            fileURL: URL(fileURLWithPath: "/tmp/vault/n2.md"),
            title: "Note 2",
            body: "Body 2",
            created: Date(),
            updated: Date(),
            modifiedAt: Date()
        )

        indexer.index(notes: [note1, note2], vaultName: "TestVault")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(mockIndex.indexedItems.count, 2)
        XCTAssertEqual(mockIndex.indexedItems.map(\.uniqueIdentifier).sorted(), ["n1.md", "n2.md"])

        indexer.deindex(ids: ["n1.md"])
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(mockIndex.deletedIDs, ["n1.md"])

        indexer.reindexAll(notes: [note2], vaultName: "TestVault")
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(mockIndex.deletedDomains, ["test.banal.notes"])
    }

    func testNoteStoreLifecycleWithSpotlight() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let mockIndexer = MockNoteSpotlightIndexer()
        let store = NoteStore(
            configuration: vault,
            monitor: nil,
            writeDebounceNanoseconds: 10_000_000,
            spotlightIndexer: mockIndexer
        )

        try store.open()
        XCTAssertFalse(mockIndexer.reindexedNotes.isEmpty)

        // 1. Create note
        let note = try store.createNote(title: "First Note", body: "Hello world")
        XCTAssertTrue(mockIndexer.indexedNotes.contains(where: { $0.id == note.id }))

        // 2. Move note
        try store.createFolder(name: "Archive")
        let moved = try store.moveNote(id: note.id, toFolder: "Archive")
        XCTAssertTrue(mockIndexer.deindexedIDs.contains(note.id))
        XCTAssertTrue(mockIndexer.indexedNotes.contains(where: { $0.id == moved.id }))

        // 3. Rename folder
        let renamed = try store.renameFolder(id: "Archive", to: "OldArchive")
        XCTAssertTrue(mockIndexer.deindexedIDs.contains(moved.id))
        let leaf = (moved.id as NSString).lastPathComponent
        XCTAssertTrue(mockIndexer.indexedNotes.contains(where: { $0.id == "\(renamed.id)/\(leaf)" }))

        // 4. Trash note
        let latestNoteID = store.notes.first { $0.title == "First Note" }!.id
        try store.trash(id: latestNoteID)
        XCTAssertTrue(mockIndexer.deindexedIDs.contains(latestNoteID))
    }

    func testNoteStoreTrashFolderDeindexesAllContainedNotes() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let mockIndexer = MockNoteSpotlightIndexer()
        let store = NoteStore(
            configuration: vault,
            monitor: nil,
            writeDebounceNanoseconds: 10_000_000,
            spotlightIndexer: mockIndexer
        )
        try store.open()

        try store.createFolder(name: "Recipes")
        let r1 = try store.createNote(title: "Soup", folder: "Recipes", language: .cooklang)
        let r2 = try store.createNote(title: "Salad", folder: "Recipes", language: .cooklang)

        try store.trashFolder(id: "Recipes")
        XCTAssertTrue(mockIndexer.deindexedIDs.contains(r1.id))
        XCTAssertTrue(mockIndexer.deindexedIDs.contains(r2.id))
    }
}
