import AppKit
@testable import BANALCore
import Foundation
import Testing
import UniformTypeIdentifiers

@Suite("Note Drag Provider Tests (G-5)")
struct NoteDragProviderTests {

    @Test("NoteDragProvider registers fileURL and plain text representations")
    func testNoteDragProviderRegistrations() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("sample-recipe.cook")
        try? ">> title: Risotto\nAdd @rice{300%g} to the pan.\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let note = Note(
            id: "Recipes/sample-recipe.cook",
            fileURL: fileURL,
            title: "Risotto",
            body: ">> title: Risotto\nAdd @rice{300%g} to the pan.\n",
            created: Date(),
            updated: Date(),
            modifiedAt: Date()
        )

        let provider = NoteDragProvider.itemProvider(for: note)

        #expect(provider.suggestedName == "sample-recipe.cook")
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier))
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier))
    }

    @Test("NoteDragProvider loads fileURL asynchronously")
    func testNoteDragProviderLoadsFileURL() async throws {
        let fileURL = URL(fileURLWithPath: "/tmp/vault/note.md")
        let note = Note(
            id: "note.md",
            fileURL: fileURL,
            title: "My Note",
            body: "This is note content.",
            created: Date(),
            updated: Date(),
            modifiedAt: Date()
        )

        let provider = NoteDragProvider.itemProvider(for: note)

        let loadedURL: URL? = try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let url = item as? NSURL {
                    continuation.resume(returning: url as URL)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let str = String(data: data, encoding: .utf8), let url = URL(string: str) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }

        #expect(loadedURL?.path == fileURL.path)
    }

    @Test("NoteDragProvider loads plain text asynchronously")
    func testNoteDragProviderLoadsPlainText() async throws {
        let fileURL = URL(fileURLWithPath: "/tmp/vault/note.md")
        let note = Note(
            id: "note.md",
            fileURL: fileURL,
            title: "My Note",
            body: "This is note content.",
            created: Date(),
            updated: Date(),
            modifiedAt: Date()
        )

        let provider = NoteDragProvider.itemProvider(for: note)

        let loadedText: String? = try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let str = item as? String {
                    continuation.resume(returning: str)
                } else if let str = item as? NSString {
                    continuation.resume(returning: str as String)
                } else if let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: str)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }

        #expect(loadedText?.contains("My Note") == true)
        #expect(loadedText?.contains("This is note content.") == true)
    }

    @Test("Finder file drag-out simulation creates byte-identical copy")
    func testFinderFileCopySimulation() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceFile = tempDir.appendingPathComponent("exported-note.md")
        let noteContent = "---\ntitle: Exported Note\n---\n\n# System Drag Out\nReal file on disk."
        try noteContent.write(to: sourceFile, atomically: true, encoding: .utf8)

        let note = Note(
            id: "exported-note.md",
            fileURL: sourceFile,
            title: "Exported Note",
            body: noteContent,
            created: Date(),
            updated: Date(),
            modifiedAt: Date()
        )

        let provider = NoteDragProvider.itemProvider(for: note)

        let resolvedURL: URL? = try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let url = item as? NSURL {
                    continuation.resume(returning: url as URL)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let str = String(data: data, encoding: .utf8), let url = URL(string: str) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }

        let fileURL = try #require(resolvedURL)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        // Simulate Finder dropping onto Desktop / another directory
        let desktopSimDir = tempDir.appendingPathComponent("Desktop")
        try FileManager.default.createDirectory(at: desktopSimDir, withIntermediateDirectories: true)
        let destination = desktopSimDir.appendingPathComponent(fileURL.lastPathComponent)

        try FileManager.default.copyItem(at: fileURL, to: destination)
        #expect(FileManager.default.fileExists(atPath: destination.path))

        let copiedContent = try String(contentsOf: destination, encoding: .utf8)
        #expect(copiedContent == noteContent)
    }

    @Test("Textile and Cooklang drag-out representations")
    func testTextileAndCooklangDragOut() async throws {
        let textileNote = Note(
            id: "article.textile",
            fileURL: URL(fileURLWithPath: "/tmp/vault/article.textile"),
            title: "Textile Article",
            body: "h1. Headline\n\nParagraph text.",
            created: Date(),
            updated: Date(),
            modifiedAt: Date()
        )

        let textileProvider = NoteDragProvider.itemProvider(for: textileNote)
        #expect(textileProvider.suggestedName == "article.textile")
        #expect(textileProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
        #expect(textileProvider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier))

        let cookNote = Note(
            id: "Recipes/sauce.cook",
            fileURL: URL(fileURLWithPath: "/tmp/vault/Recipes/sauce.cook"),
            title: "Hollandaise",
            body: ">> title: Hollandaise\nWhisk egg yolks.",
            created: Date(),
            updated: Date(),
            modifiedAt: Date()
        )

        let cookProvider = NoteDragProvider.itemProvider(for: cookNote)
        #expect(cookProvider.suggestedName == "sauce.cook")
        #expect(cookProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
        #expect(cookProvider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier))
    }
}

extension NoteDragProviderTests {
    @Test("Drop note URL resolution matches note in vault and moves file")
    @MainActor func testDropNoteURLResolutionAndMove() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let config = VaultConfiguration(rootURL: tempDir)
        try VaultBootstrap.prepare(config)
        let store = NoteStore(configuration: config, monitor: nil)
        try store.open()

        let folder = try store.createFolder(name: "Recipes")
        let note = try store.createNote(title: "Risotto", folder: nil, language: .cooklang)

        #expect(note.folder == nil)
        #expect(FileManager.default.fileExists(atPath: note.fileURL.path))

        // Find note by URL and move to target folder
        let match = store.notes.first(where: { $0.fileURL.standardizedFileURL == note.fileURL.standardizedFileURL })
        let matchedNote = try #require(match)
        let moved = try store.moveNote(id: matchedNote.id, toFolder: folder.id)

        #expect(moved.folder == "Recipes")
        #expect(FileManager.default.fileExists(atPath: moved.fileURL.path))
    }
}
