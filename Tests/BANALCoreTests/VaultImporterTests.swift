import XCTest
@testable import BANALCore

@MainActor
final class VaultImporterTests: XCTestCase {
    private func makeVault() throws -> VaultConfiguration {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-vault-\(UUID().uuidString)", isDirectory: true)
        let configuration = VaultConfiguration(rootURL: root)
        try VaultBootstrap.prepare(configuration)
        return configuration
    }

    private func makeSourceDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("banal-source-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testSingleMarkdownFileImport() throws {
        let vault = try makeVault()
        let sourceDir = try makeSourceDir()
        defer {
            try? FileManager.default.removeItem(at: vault.rootURL)
            try? FileManager.default.removeItem(at: sourceDir)
        }

        let sourceFile = sourceDir.appendingPathComponent("ImportedNote.md")
        let content = "---\ntitle: Imported Note\ntags: [imported]\n---\n\nHello from external source."
        try content.write(to: sourceFile, atomically: true, encoding: .utf8)

        let result = try VaultImporter.importItems(from: [sourceFile], into: vault)

        XCTAssertEqual(result.noteCount, 1)
        XCTAssertEqual(result.assetCount, 0)
        XCTAssertEqual(result.totalCount, 1)
        XCTAssertEqual(result.notePaths, ["ImportedNote.md"])
        XCTAssertEqual(result.importedNotes.count, 1)

        let importedNote = result.importedNotes[0]
        XCTAssertEqual(importedNote.title, "Imported Note")
        XCTAssertEqual(importedNote.tags, ["imported"])
        XCTAssertTrue(importedNote.body.contains("Hello from external source."))

        let vaultFile = vault.rootURL.appendingPathComponent("ImportedNote.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultFile.path))
    }

    func testSingleTextileAndCooklangImport() throws {
        let vault = try makeVault()
        let sourceDir = try makeSourceDir()
        defer {
            try? FileManager.default.removeItem(at: vault.rootURL)
            try? FileManager.default.removeItem(at: sourceDir)
        }

        let textileFile = sourceDir.appendingPathComponent("essay.textile")
        try "h1. An Essay\n\nSome textile content.".write(to: textileFile, atomically: true, encoding: .utf8)

        let cookFile = sourceDir.appendingPathComponent("risotto.cook")
        try ">> title: Risotto\nAdd @rice{200%g} to pan.".write(to: cookFile, atomically: true, encoding: .utf8)

        let result = try VaultImporter.importItems(from: [textileFile, cookFile], into: vault)

        XCTAssertEqual(result.noteCount, 2)
        XCTAssertEqual(result.assetCount, 0)
        XCTAssertTrue(result.notePaths.contains("essay.textile"))
        XCTAssertTrue(result.notePaths.contains("risotto.cook"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("essay.textile").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("risotto.cook").path))
    }

    func testTxtAndMarkdownExtensionNormalization() throws {
        let vault = try makeVault()
        let sourceDir = try makeSourceDir()
        defer {
            try? FileManager.default.removeItem(at: vault.rootURL)
            try? FileManager.default.removeItem(at: sourceDir)
        }

        let txtFile = sourceDir.appendingPathComponent("scratchpad.txt")
        try "Plain text note content.".write(to: txtFile, atomically: true, encoding: .utf8)

        let markdownFile = sourceDir.appendingPathComponent("guide.markdown")
        try "# Guide\n\nDetailed instructions.".write(to: markdownFile, atomically: true, encoding: .utf8)

        let result = try VaultImporter.importItems(from: [txtFile, markdownFile], into: vault)

        XCTAssertEqual(result.noteCount, 2)
        XCTAssertTrue(result.notePaths.contains("scratchpad.md"))
        XCTAssertTrue(result.notePaths.contains("guide.md"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("scratchpad.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("guide.md").path))
    }

    func testCollisionHandlingAutoRenames() throws {
        let vault = try makeVault()
        let sourceDir = try makeSourceDir()
        defer {
            try? FileManager.default.removeItem(at: vault.rootURL)
            try? FileManager.default.removeItem(at: sourceDir)
        }

        // Pre-create Note.md in vault
        let existingNote = vault.rootURL.appendingPathComponent("Daily.md")
        try "---\ntitle: Existing Daily\n---\nOriginal.".write(to: existingNote, atomically: true, encoding: .utf8)

        // Source Note.md
        let sourceFile = sourceDir.appendingPathComponent("Daily.md")
        try "---\ntitle: New Daily\n---\nImported 1.".write(to: sourceFile, atomically: true, encoding: .utf8)

        // Another source Note.txt which normalizes to Daily.md
        let sourceFile2 = sourceDir.appendingPathComponent("Daily.txt")
        try "Imported 2.".write(to: sourceFile2, atomically: true, encoding: .utf8)

        let result = try VaultImporter.importItems(from: [sourceFile, sourceFile2], into: vault)

        XCTAssertEqual(result.noteCount, 2)
        XCTAssertTrue(result.notePaths.contains("Daily-2.md"))
        XCTAssertTrue(result.notePaths.contains("Daily-3.md"))

        // Original file must be preserved intact
        let originalContent = try String(contentsOf: existingNote, encoding: .utf8)
        XCTAssertTrue(originalContent.contains("Existing Daily"))

        // Newly imported files must exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("Daily-2.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("Daily-3.md").path))
    }

    func testRecursiveFolderImportWithNestedSubdirectoriesAndAssets() throws {
        let vault = try makeVault()
        let sourceDir = try makeSourceDir()
        defer {
            try? FileManager.default.removeItem(at: vault.rootURL)
            try? FileManager.default.removeItem(at: sourceDir)
        }

        // Build simulated Obsidian / Bear folder
        let obsidianDir = sourceDir.appendingPathComponent("ObsidianVault", isDirectory: true)
        let subDir = obsidianDir.appendingPathComponent("Projects/Deep", isDirectory: true)
        let assetsDir = obsidianDir.appendingPathComponent("assets", isDirectory: true)
        let hiddenDir = obsidianDir.appendingPathComponent(".obsidian", isDirectory: true)

        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: hiddenDir, withIntermediateDirectories: true)

        // Notes
        try "# Root Note".write(to: obsidianDir.appendingPathComponent("Root.md"), atomically: true, encoding: .utf8)
        try ">> title: Soup\n@water".write(to: obsidianDir.appendingPathComponent("Soup.cook"), atomically: true, encoding: .utf8)
        try "Deep content".write(to: subDir.appendingPathComponent("DeepNote.txt"), atomically: true, encoding: .utf8)

        // Assets
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: assetsDir.appendingPathComponent("diagram.png"))
        try Data([0xFF, 0xD8, 0xFF]).write(to: subDir.appendingPathComponent("photo.jpg"))

        // Files to skip
        try "{}".write(to: hiddenDir.appendingPathComponent("workspace.json"), atomically: true, encoding: .utf8)
        try "junk".write(to: obsidianDir.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)
        try Data([0x00, 0x01]).write(to: obsidianDir.appendingPathComponent("program.exe"))

        let result = try VaultImporter.importItems(from: [obsidianDir], into: vault)

        XCTAssertEqual(result.noteCount, 3)
        XCTAssertEqual(result.assetCount, 2)
        XCTAssertEqual(result.totalCount, 5)

        XCTAssertTrue(result.notePaths.contains("Root.md"))
        XCTAssertTrue(result.notePaths.contains("Soup.cook"))
        XCTAssertTrue(result.notePaths.contains("Projects/Deep/DeepNote.md"))

        XCTAssertTrue(result.assetPaths.contains("assets/diagram.png"))
        XCTAssertTrue(result.assetPaths.contains("Projects/Deep/photo.jpg"))

        // Verify files on disk
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("Root.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("Soup.cook").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("Projects/Deep/DeepNote.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("assets/diagram.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("Projects/Deep/photo.jpg").path))

        // Skipped items must NOT be present
        XCTAssertFalse(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent(".obsidian").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("program.exe").path))
    }

    func testImportIntoTargetFolder() throws {
        let vault = try makeVault()
        let sourceDir = try makeSourceDir()
        defer {
            try? FileManager.default.removeItem(at: vault.rootURL)
            try? FileManager.default.removeItem(at: sourceDir)
        }

        let noteFile = sourceDir.appendingPathComponent("meeting.md")
        try "# Meeting".write(to: noteFile, atomically: true, encoding: .utf8)

        let result = try VaultImporter.importItems(from: [noteFile], into: vault, targetFolder: "Archive/2026")

        XCTAssertEqual(result.noteCount, 1)
        XCTAssertEqual(result.notePaths, ["Archive/2026/meeting.md"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("Archive/2026/meeting.md").path))
    }

    func testStandaloneImageAssetImport() throws {
        let vault = try makeVault()
        let sourceDir = try makeSourceDir()
        defer {
            try? FileManager.default.removeItem(at: vault.rootURL)
            try? FileManager.default.removeItem(at: sourceDir)
        }

        let imageFile = sourceDir.appendingPathComponent("logo.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: imageFile)

        let result = try VaultImporter.importItems(from: [imageFile], into: vault)

        XCTAssertEqual(result.noteCount, 0)
        XCTAssertEqual(result.assetCount, 1)
        XCTAssertEqual(result.assetPaths, ["assets/logo.png"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: vault.rootURL.appendingPathComponent("assets/logo.png").path))
    }

    func testImportFromInsideVaultThrowsWhenSingle() throws {
        let vault = try makeVault()
        defer {
            try? FileManager.default.removeItem(at: vault.rootURL)
        }

        let inVaultFile = vault.rootURL.appendingPathComponent("Welcome.md")
        XCTAssertThrowsError(try VaultImporter.importItems(from: [inVaultFile], into: vault)) { error in
            XCTAssertEqual(error as? NoteStoreError, NoteStoreError.noteAlreadyInVault)
        }
    }

    func testNoteStoreImportItemsIntegrates() throws {
        let vault = try makeVault()
        let sourceDir = try makeSourceDir()
        defer {
            try? FileManager.default.removeItem(at: vault.rootURL)
            try? FileManager.default.removeItem(at: sourceDir)
        }

        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let noteFile = sourceDir.appendingPathComponent("Idea.md")
        try "---\ntitle: Big Idea\n---\nRevolutionary.".write(to: noteFile, atomically: true, encoding: .utf8)

        let result = try store.importItems(from: [noteFile])

        XCTAssertEqual(result.noteCount, 1)
        XCTAssertEqual(result.summary, "Imported 1 note into the notes folder.")
        XCTAssertNotNil(store.note(id: "Idea.md"))
        XCTAssertEqual(store.note(id: "Idea.md")?.title, "Big Idea")
    }
}
