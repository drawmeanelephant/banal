import XCTest
@testable import BANALCore

@MainActor
final class IngredientSearchTests: XCTestCase {
    // MARK: - CooklangScanner Token Extraction

    func testCooklangScannerExtractsBareAndBracedTokens() {
        let source = """
        >> title: Test Recipe
        >> servings: 4
        -- a comment with @fake{}

        Warm @stock{1%l} in #saucepan{}.
        Toast @arborio rice{300%g} with @olive oil{2%tbsp}.
        Fold in @parmesan{50%g}(grated) and @butter{40%g}.
        Season with @salt and @black pepper{}.
        Add a pinch of @saffron{} and @kosher-salt.
        Wait for ~{10%minutes}.
        """

        let names = CooklangScanner.ingredientNames(in: source)
        XCTAssertEqual(
            names,
            ["stock", "arborio rice", "olive oil", "parmesan", "butter", "salt", "black pepper", "saffron", "kosher-salt"]
        )
    }

    func testCooklangScannerBareIngredientWithPunctuation() {
        let source = "Season with @salt, @pepper, and @paprika! Garnish with @parsley (optional)."
        let names = CooklangScanner.ingredientNames(in: source)
        XCTAssertEqual(names, ["salt", "pepper", "paprika", "parsley"])
    }

    func testCooklangScannerIgnoresMetadataAndCookwareAndTimers() {
        let source = """
        >> title: Soup with @carrots
        >> tags: dinner, soup
        -- Don't forget @celery

        Heat #wide pot{} for ~{5%minutes}.
        Add @onions{} and @garlic.
        """
        let names = CooklangScanner.ingredientNames(in: source)
        XCTAssertEqual(names, ["onions", "garlic"])
        XCTAssertFalse(names.contains("carrots"))
        XCTAssertFalse(names.contains("celery"))
        XCTAssertFalse(names.contains("wide pot"))
    }

    // MARK: - Sauce Inlining Scanner

    func testCooklangScannerWalksReferencedSauces() throws {
        let vault = try makeVault([
            "Recipes/risotto.cook": """
            >> title: Risotto
            Warm @stock{1%l}.
            Toast @arborio rice{300%g}.
            Serve with @./sauces/Hollandaise{150%g}
            """,
            "Recipes/sauces/Hollandaise.cook": """
            >> title: Hollandaise
            Whisk @egg yolk{2} with @lemon juice{1%tbsp}.
            Melt @butter{100%g}.
            """
        ])
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let risottoURL = vault.rootURL.appendingPathComponent("Recipes/risotto.cook")
        let source = try String(contentsOf: risottoURL, encoding: .utf8)
        let names = CooklangScanner.ingredientNames(in: source, relativeTo: risottoURL.deletingLastPathComponent())

        XCTAssertTrue(names.contains("stock"))
        XCTAssertTrue(names.contains("arborio rice"))
        XCTAssertTrue(names.contains("egg yolk"))
        XCTAssertTrue(names.contains("lemon juice"))
        XCTAssertTrue(names.contains("butter"))
        XCTAssertFalse(names.contains("./sauces/Hollandaise"))
    }

    func testCooklangScannerHandlesSauceCycleAndBoundedDepth() throws {
        let vault = try makeVault([
            "a.cook": "Add @salt{}. Use @./b.\n",
            "b.cook": "Add @pepper{}. Use @./a.\n"
        ])
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let aURL = vault.rootURL.appendingPathComponent("a.cook")
        let source = try String(contentsOf: aURL, encoding: .utf8)
        let names = CooklangScanner.ingredientNames(in: source, relativeTo: vault.rootURL)

        XCTAssertTrue(names.contains("salt"))
        XCTAssertTrue(names.contains("pepper"))
    }

    // MARK: - Note.matches & NoteStore Search

    func testQueryMatchesRecipeIngredients() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        var recipe = try store.createNote(title: "Milanese", language: .cooklang)
        recipe.body = """
        Warm @stock{1%l}.
        Add a pinch of @saffron{} to the broth.
        Toast @arborio rice{300%g} with @olive oil{2%tbsp}.
        """
        store.update(recipe, debounce: false)

        var note = try store.createNote(title: "Gardening", language: .markdown)
        note.body = "Planting tomatoes in spring."
        store.update(note, debounce: false)

        // Single word ingredient search
        let saffronHits = store.notes(matching: .all, query: "saffron")
        XCTAssertEqual(saffronHits.map(\.title), ["Milanese"])

        // Case-insensitive ingredient search
        let upperHits = store.notes(matching: .all, query: "SAFFRON")
        XCTAssertEqual(upperHits.map(\.title), ["Milanese"])

        // Multi-word ingredient matching either word or full phrase
        let arborioHits = store.notes(matching: .all, query: "arborio")
        XCTAssertEqual(arborioHits.map(\.title), ["Milanese"])

        let phraseHits = store.notes(matching: .all, query: "arborio rice")
        XCTAssertEqual(phraseHits.map(\.title), ["Milanese"])

        let oilHits = store.notes(matching: .all, query: "olive oil")
        XCTAssertEqual(oilHits.map(\.title), ["Milanese"])

        // Non-matching query returns empty
        let cuminHits = store.notes(matching: .all, query: "cumin")
        XCTAssertTrue(cuminHits.isEmpty)
    }

    func testQueryMatchesInlinedSauceIngredients() throws {
        let vault = try makeVault([
            "Recipes/risotto.cook": """
            >> title: Risotto
            Warm @stock{1%l}.
            Toast @arborio rice{300%g}.
            Serve with @./sauces/Hollandaise{150%g}
            """,
            "Recipes/sauces/Hollandaise.cook": """
            >> title: Hollandaise
            Whisk @egg yolk{2} with @lemon juice{1%tbsp}.
            Melt @butter{100%g}.
            """
        ])
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let eggYolkHits = store.notes(matching: .all, query: "egg yolk")
        XCTAssertTrue(eggYolkHits.contains { $0.title == "Risotto" })
        XCTAssertTrue(eggYolkHits.contains { $0.title == "Hollandaise" })

        let lemonHits = store.notes(matching: .all, query: "lemon juice")
        XCTAssertTrue(lemonHits.contains { $0.title == "Risotto" })

        let yolkHits = store.notes(matching: .all, query: "yolk")
        XCTAssertTrue(yolkHits.contains { $0.title == "Risotto" })
    }

    // MARK: - In-Memory Cache & Invalidation

    func testIngredientCacheInvalidatesOnContentChange() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        var recipe = try store.createNote(title: "Risotto", language: .cooklang)
        recipe.body = "Add @saffron{} to the broth.\n"
        store.update(recipe, debounce: false)

        let initialNote = try XCTUnwrap(store.note(id: recipe.id))
        let initialIngredients = store.ingredients(for: initialNote)
        XCTAssertEqual(initialIngredients, ["saffron"])
        XCTAssertEqual(store.cachedIngredients(for: initialNote.id, fingerprint: initialNote.contentFingerprint), ["saffron"])

        // Edit recipe to remove saffron and add turmeric
        var edited = initialNote
        edited.body = "Add @turmeric{} to the broth.\n"
        store.update(edited, debounce: false)

        let updatedNote = try XCTUnwrap(store.note(id: recipe.id))
        XCTAssertNotEqual(updatedNote.contentFingerprint, initialNote.contentFingerprint)

        // Old fingerprint returns nil from cache
        XCTAssertNil(store.cachedIngredients(for: updatedNote.id, fingerprint: initialNote.contentFingerprint))

        // New lookup populates new cache
        let updatedIngredients = store.ingredients(for: updatedNote)
        XCTAssertEqual(updatedIngredients, ["turmeric"])
        XCTAssertEqual(store.cachedIngredients(for: updatedNote.id, fingerprint: updatedNote.contentFingerprint), ["turmeric"])

        // Search reflects new content
        XCTAssertTrue(store.notes(matching: .all, query: "saffron").isEmpty)
        XCTAssertEqual(store.notes(matching: .all, query: "turmeric").map(\.title), ["Risotto"])
    }

    func testCachedIngredientsExplicitOverride() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let recipe = try store.createNote(title: "Special", language: .cooklang)
        let loaded = try XCTUnwrap(store.note(id: recipe.id))

        // Simulate Oliver caching parsed ingredients
        store.setCachedIngredients(["vanilla bean", "cardamom"], for: loaded.id, fingerprint: loaded.contentFingerprint)

        XCTAssertEqual(store.cachedIngredients(for: loaded.id, fingerprint: loaded.contentFingerprint), ["vanilla bean", "cardamom"])
        XCTAssertEqual(store.notes(matching: .all, query: "cardamom").map(\.title), ["Special"])
        XCTAssertEqual(store.notes(matching: .all, query: "vanilla bean").map(\.title), ["Special"])
    }

    func testTrashAndMoveCleanUpCache() throws {
        let vault = try makeVault()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        _ = try store.createFolder(name: "Recipes")
        var recipe = try store.createNote(title: "Curry", folder: "Recipes", language: .cooklang)
        recipe.body = "Add @cardamom{} and @turmeric{}.\n"
        store.update(recipe, debounce: false)

        let loaded = try XCTUnwrap(store.note(id: recipe.id))
        _ = store.ingredients(for: loaded)
        XCTAssertNotNil(store.cachedIngredients(for: loaded.id, fingerprint: loaded.contentFingerprint))

        // Trash note removes cache entry
        try store.trash(id: loaded.id)
        XCTAssertNil(store.cachedIngredients(for: loaded.id, fingerprint: loaded.contentFingerprint))
    }

    // MARK: - Standalone Note.matches

    func testStandaloneNoteMatchesTokensDirectly() {
        let note = Note(
            id: "risotto.cook",
            fileURL: URL(fileURLWithPath: "/tmp/risotto.cook"),
            title: "Risotto",
            body: "Toast @arborio rice{300%g} with @olive oil{2%tbsp}. Add @saffron.",
            created: Date(),
            updated: Date(),
            modifiedAt: Date()
        )

        XCTAssertTrue(note.matches(query: "saffron"))
        XCTAssertTrue(note.matches(query: "arborio"))
        XCTAssertTrue(note.matches(query: "arborio rice"))
        XCTAssertTrue(note.matches(query: "olive oil"))
        XCTAssertFalse(note.matches(query: "cumin"))
    }

    // MARK: - Missing Oliver Fallback & Chained Sauces

    func testMissingOliverSearchesFileBodyAndTokensAccurately() throws {
        let vault = try makeVault([
            "pasta.cook": "Boil @spaghetti{200%g} in salted water. Toss with @garlic and @pecorino{50%g}."
        ])
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        // With oliverBinaryPath pointing to a non-existent binary (missing Oliver)
        var config = vault
        config.oliverBinaryPath = "/tmp/banal-missing-oliver-\(UUID().uuidString)"
        let store = NoteStore(configuration: config, monitor: nil)
        try store.open()

        let spaghettiHits = store.notes(matching: .all, query: "spaghetti")
        XCTAssertEqual(spaghettiHits.map(\.title), ["pasta"])

        let garlicHits = store.notes(matching: .all, query: "garlic")
        XCTAssertEqual(garlicHits.map(\.title), ["pasta"])

        let pecorinoHits = store.notes(matching: .all, query: "pecorino")
        XCTAssertEqual(pecorinoHits.map(\.title), ["pasta"])

        let waterHits = store.notes(matching: .all, query: "salted water")
        XCTAssertEqual(waterHits.map(\.title), ["pasta"])
    }

    func testChainedSauceWalkingExtractsAllIngredients() throws {
        let vault = try makeVault([
            "a.cook": "Add @salt{}. Use @./b.\n",
            "b.cook": "Add @mustard{}. Use @./c.\n",
            "c.cook": "Add @honey{}.\n"
        ])
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }

        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let honeyHits = store.notes(matching: .all, query: "honey")
        XCTAssertTrue(honeyHits.contains { $0.title == "a" })
        XCTAssertTrue(honeyHits.contains { $0.title == "b" })
        XCTAssertTrue(honeyHits.contains { $0.title == "c" })

        let mustardHits = store.notes(matching: .all, query: "mustard")
        XCTAssertTrue(mustardHits.contains { $0.title == "a" })
        XCTAssertTrue(mustardHits.contains { $0.title == "b" })
        XCTAssertFalse(mustardHits.contains { $0.title == "c" })
    }

    // MARK: - Helpers

    private func makeVault(_ files: [String: String] = [:]) throws -> VaultConfiguration {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("banal-d4-\(UUID().uuidString)", isDirectory: true)
        let configuration = VaultConfiguration(rootURL: root)
        try VaultBootstrap.prepare(configuration)
        for (relative, contents) in files {
            let url = root.appendingPathComponent(relative)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(contents.utf8).write(to: url)
        }
        return configuration
    }
}
