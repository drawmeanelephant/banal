import XCTest
@testable import BANALCore

@MainActor
final class NoteLanguageTests: XCTestCase {
    func testCreateEachKindReloadPreservesExtension() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let essay = try store.createNote(title: "An essay", language: .markdown)
        let page = try store.createNote(title: "A page", language: .textile)
        let risotto = try store.createNote(title: "Risotto", language: .cooklang)

        XCTAssertEqual(essay.fileURL.pathExtension, "md")
        XCTAssertEqual(page.fileURL.pathExtension, "textile")
        XCTAssertEqual(risotto.fileURL.pathExtension, "cook")
        XCTAssertEqual(essay.language, .markdown)
        XCTAssertEqual(page.language, .textile)
        XCTAssertEqual(risotto.language, .cooklang)

        try store.reloadAll()

        let reEssay = try XCTUnwrap(store.note(id: essay.id))
        let rePage = try XCTUnwrap(store.note(id: page.id))
        let reRisotto = try XCTUnwrap(store.note(id: risotto.id))
        XCTAssertEqual(reEssay.fileURL.pathExtension, "md")
        XCTAssertEqual(rePage.fileURL.pathExtension, "textile")
        XCTAssertEqual(reRisotto.fileURL.pathExtension, "cook")
        XCTAssertEqual(reEssay.title, "An essay")
        XCTAssertEqual(rePage.title, "A page")
        XCTAssertEqual(reRisotto.title, "Risotto")
        XCTAssertEqual(store.notes(matching: .all).count, 4, "Welcome plus three languages")
    }

    func testScanFindsDroppedFilesAndSkipsReserved() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        try Data("h1. From Finder\n".utf8).write(to: vault.rootURL.appendingPathComponent("from-finder.textile"))
        try Data("Add @salt{}\n\nSimmer.\n".utf8).write(to: vault.rootURL.appendingPathComponent("from-finder.cook"))
        try Data("# not a note\n".utf8).write(to: vault.assetsURL.appendingPathComponent("ignored.md"))
        try Data("nope\n".utf8).write(to: vault.rootURL.appendingPathComponent("notes.txt"))

        try store.reloadAll()

        XCTAssertNotNil(store.note(id: "from-finder.textile"))
        XCTAssertNotNil(store.note(id: "from-finder.cook"))
        XCTAssertNil(store.notes.first { $0.fileURL.lastPathComponent == "ignored.md" })
        XCTAssertNil(store.notes.first { $0.fileURL.pathExtension == "txt" })

        let droppedCook = try XCTUnwrap(store.note(id: "from-finder.cook"))
        XCTAssertEqual(droppedCook.title, "from-finder", "a cook file without >> title uses the filename, not the first step")
        XCTAssertFalse(droppedCook.title.contains("@"))
    }

    func testSameStemDifferentExtensionsCoexist() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let now = DateFormatting.date(from: "2026-08-18T12:00:00Z")!
        let md = try store.createNote(title: "hello", language: .markdown, now: now)
        let cook = try store.createNote(title: "hello", language: .cooklang, now: now)
        XCTAssertEqual((md.id as NSString).deletingPathExtension, (cook.id as NSString).deletingPathExtension)
        XCTAssertNotEqual(md.id, cook.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: md.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: cook.fileURL.path))
    }

    func testCookFileIsNotYAMLAndKeepsCooklangMetadata() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let recipe = try store.createNote(title: "Risotto", language: .cooklang)
        let source = try String(contentsOf: recipe.fileURL, encoding: .utf8)
        XCTAssertFalse(source.hasPrefix("---"), "cook files must not get a YAML fence")
        XCTAssertTrue(source.contains(">> title: Risotto"))
        XCTAssertTrue(source.contains("@ingredient{}"))
        XCTAssertTrue(source.contains("Stir."))
        XCTAssertFalse(source.contains("created:"))

        var published = recipe
        published.published = true
        published.tags = ["dinner"]
        published.body = ">> servings: 4\n\nAdd @arborio rice{300%g} to the pan.\n\nStir.\n"
        store.update(published, debounce: false)

        let disk = try String(contentsOf: recipe.fileURL, encoding: .utf8)
        XCTAssertFalse(disk.contains("\n---\n") || disk.hasPrefix("---"))
        XCTAssertTrue(disk.contains(">> title: Risotto"))
        XCTAssertTrue(disk.contains(">> tags: dinner"))
        XCTAssertTrue(disk.contains(">> published: true"))
        XCTAssertTrue(disk.contains(">> servings: 4"))

        try store.reloadAll()
        let loaded = try XCTUnwrap(store.note(id: recipe.id))
        XCTAssertEqual(loaded.title, "Risotto")
        XCTAssertEqual(loaded.tags, ["dinner"])
        XCTAssertTrue(loaded.published)
        XCTAssertTrue(loaded.body.contains(">> servings: 4"))
        XCTAssertTrue(loaded.body.contains("@arborio rice{300%g}"))
        XCTAssertFalse(loaded.body.contains(">> title:"))
    }

    func testTextileUsesFrontmatterAndSearchMatchesAllKinds() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        var page = try store.createNote(title: "Cloth", language: .textile)
        page.body = "\nh1. A textile page\n\nRed cloth on the line.\n"
        store.update(page, debounce: false)

        var recipe = try store.createNote(title: "Broth", language: .cooklang)
        recipe.body = "Simmer @bones{} overnight.\n"
        store.update(recipe, debounce: false)

        let textileSource = try String(contentsOf: page.fileURL, encoding: .utf8)
        XCTAssertTrue(textileSource.hasPrefix("---"))
        XCTAssertTrue(textileSource.contains("title: Cloth"))

        XCTAssertEqual(store.notes(matching: .all, query: "cloth").map(\.title), ["Cloth"])
        XCTAssertEqual(store.notes(matching: .all, query: "bones").map(\.title), ["Broth"])
        XCTAssertTrue(
            store.notes(matching: .all, query: "bones").allSatisfy { $0.language == .cooklang }
        )
    }

    func testMoveAndFolderRenameKeepCookExtension() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        _ = try store.createFolder(name: "Recipes")
        let recipe = try store.createNote(title: "Pesto", folder: "Recipes", language: .cooklang)
        XCTAssertEqual(recipe.fileURL.pathExtension, "cook")

        _ = try store.createFolder(name: "Sauces")
        let moved = try store.moveNote(id: recipe.id, toFolder: "Sauces")
        XCTAssertEqual(moved.folder, "Sauces")
        XCTAssertEqual(moved.fileURL.pathExtension, "cook")
        XCTAssertTrue(moved.fileURL.lastPathComponent.hasSuffix(".cook"))

        let renamed = try store.renameFolder(id: "Sauces", to: "Jars")
        XCTAssertEqual(renamed.id, "Jars")
        let after = try XCTUnwrap(store.notes.first { $0.title == "Pesto" })
        XCTAssertEqual(after.folder, "Jars")
        XCTAssertEqual(after.fileURL.pathExtension, "cook")
        XCTAssertTrue(FileManager.default.fileExists(atPath: after.fileURL.path))
    }

    func testCookYAMLFenceStaysSource() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-cook-yaml-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent("pasta.cook")
        let source = """
        ---
        servings: 2
        ---

        Boil @pasta{200%g} in salted water.
        """
        try Data(source.utf8).write(to: url)
        let loaded = try NoteIO.load(url: url, vaultURL: root)
        XCTAssertTrue(loaded.body.contains("---"))
        XCTAssertTrue(loaded.body.contains("servings: 2"))
        XCTAssertTrue(loaded.body.contains("@pasta{200%g}"))
        XCTAssertEqual(loaded.language, .cooklang)

        let encoded = NoteIO.encode(loaded)
        XCTAssertTrue(encoded.contains("---"))
        XCTAssertTrue(encoded.contains(">> title:"))
        XCTAssertFalse(encoded.hasPrefix("---"), "BANAL must not wrap cook source in its own fence")
    }

    func testExternalCookChangeIsPickedUp() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let url = vault.rootURL.appendingPathComponent("external.cook")
        try Data(">> title: From Vim\n\nAdd @eggs{}\n\nFry.\n".utf8).write(to: url)
        store.applyExternalChange(at: url)

        let note = try XCTUnwrap(store.note(id: "external.cook"))
        XCTAssertEqual(note.title, "From Vim")
        XCTAssertTrue(note.body.contains("@eggs{}"))
        XCTAssertEqual(note.language, .cooklang)
    }

    private func makeVault() throws -> VaultConfiguration {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-lang-\(UUID().uuidString)", isDirectory: true)
        let configuration = VaultConfiguration(rootURL: root)
        try VaultBootstrap.prepare(configuration)
        return configuration
    }
}

final class CookMetadataTests: XCTestCase {
    func testParseExtractsKnownKeysAndLeavesRecipeMetadata() {
        let source = """
        >> title: Risotto
        >> servings: 4
        >> published: true
        >> tags: dinner, italian

        Add @rice{300%g}.
        """
        let parsed = CookMetadata.parse(source)
        XCTAssertTrue(parsed.hasFrontmatter)
        XCTAssertEqual(parsed.frontmatter.title, "Risotto")
        XCTAssertTrue(parsed.frontmatter.published)
        XCTAssertEqual(parsed.frontmatter.tags, ["dinner", "italian"])
        XCTAssertTrue(parsed.body.contains(">> servings: 4"))
        XCTAssertTrue(parsed.body.contains("@rice{300%g}"))
        XCTAssertFalse(parsed.body.contains(">> title:"))
        XCTAssertFalse(parsed.body.contains(">> published:"))
    }

    func testSerializeDoesNotWriteYAML() {
        let encoded = CookMetadata.serialize(
            frontmatter: Frontmatter(title: "Broth", tags: ["soup"], published: false),
            body: "Simmer @bones{}.\n"
        )
        XCTAssertTrue(encoded.hasPrefix(">> title: Broth\n"))
        XCTAssertTrue(encoded.contains(">> tags: soup"))
        XCTAssertFalse(encoded.contains(">> published:"))
        XCTAssertFalse(encoded.contains("---"))
        XCTAssertTrue(encoded.contains("Simmer @bones{}."))
    }
}
