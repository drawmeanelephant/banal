import XCTest
@testable import BANALPublisher

final class RecipeInlinerTests: XCTestCase {
    private let risotto = """
    >> title: Risotto

    Warm @stock{1%l} in #saucepan{}.

    Fold in @parmesan{50%g}(grated) and @butter{40%g}.

    Season with @salt{} and @pepper{}.

    Serve with @./sauces/Hollandaise{150%g}
    """

    private let hollandaise = """
    >> title: Hollandaise

    Whisk @egg yolk{2} with @lemon juice{1%tbsp}.

    Melt @butter{100%g} and drizzle in slowly.
    """

    func testNoRefsLeavesSourceAlone() throws {
        let vault = try makeVault(["soup.cook": "Boil @stock{1%l}.\n"])
        defer { try? FileManager.default.removeItem(at: vault) }
        let result = RecipeInliner.inline(source: "Boil @stock{1%l}.\n", relativeTo: vault)
        XCTAssertEqual(result.source, "Boil @stock{1%l}.\n")
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testInlinesSauceAndHonorsRefPercent() throws {
        let vault = try makeVault([
            "Recipes/risotto.cook": risotto,
            "Recipes/sauces/Hollandaise.cook": hollandaise,
        ])
        defer { try? FileManager.default.removeItem(at: vault) }
        let directory = vault.appendingPathComponent("Recipes")

        let result = RecipeInliner.inline(
            source: risotto,
            relativeTo: directory,
            scaler: { source, percent in "SCALED(\(percent))\n\(source)" }
        )

        XCTAssertTrue(result.source.contains("egg yolk"), result.source)
        XCTAssertTrue(result.source.contains("lemon juice"), result.source)
        XCTAssertTrue(result.source.contains("SCALED(150)"), result.source)
        XCTAssertFalse(result.source.contains("@./sauces/Hollandaise"), "the ref must be replaced")
        XCTAssertTrue(result.issues.isEmpty, result.issues.joined())
        // The walk never rewrites either file.
        XCTAssertEqual(
            try String(contentsOf: vault.appendingPathComponent("Recipes/risotto.cook"), encoding: .utf8),
            risotto
        )
        XCTAssertEqual(
            try String(contentsOf: vault.appendingPathComponent("Recipes/sauces/Hollandaise.cook"), encoding: .utf8),
            hollandaise
        )
    }

    func testResolvesWithoutDotSlashAndWithoutExtension() throws {
        let vault = try makeVault([
            "a.cook": "Use @sauces/B{50%}.\n",
            "sauces/B.cook": "Add @egg yolk{2}.\n",
        ])
        defer { try? FileManager.default.removeItem(at: vault) }
        let result = RecipeInliner.inline(
            source: "Use @sauces/B{50%}.\n",
            relativeTo: vault,
            scaler: { source, percent in "SCALED(\(percent))\n\(source)" }
        )
        XCTAssertTrue(result.source.contains("SCALED(50)"), result.source)
        XCTAssertTrue(result.source.contains("egg yolk"), result.source)
        XCTAssertTrue(result.issues.isEmpty, result.issues.joined())
    }

    func testMissingSauceLeavesRefAndReportsOneSentence() throws {
        let vault = try makeVault(["a.cook": "Use @./sauces/Nope{150%g}.\n"])
        defer { try? FileManager.default.removeItem(at: vault) }
        let result = RecipeInliner.inline(source: "Use @./sauces/Nope{150%g}.\n", relativeTo: vault)
        XCTAssertTrue(result.source.contains("@./sauces/Nope"), "a missing sauce keeps its ref as text")
        XCTAssertEqual(result.issues, ["Sauce not found: ./sauces/Nope"])
    }

    func testCycleReportsOneSentence() throws {
        let vault = try makeVault([
            "a.cook": "Use @./b{100%}.\n",
            "b.cook": "Use @./a{100%}.\n",
        ])
        defer { try? FileManager.default.removeItem(at: vault) }
        let result = RecipeInliner.inline(source: "Use @./b{100%}.\n", relativeTo: vault)
        XCTAssertEqual(result.issues.count, 1, result.issues.joined())
        XCTAssertTrue(result.issues[0].hasPrefix("Sauce cycle:"), result.issues[0])
        XCTAssertTrue(result.source.contains("@./b{100%}"), "the re-entering ref is left as written")
    }

    func testWalkIsBounded() throws {
        let vault = try makeVault([
            "a.cook": "Use @./b.\n",
            "b.cook": "Use @./c.\n",
            "c.cook": "Use @./d.\n",
            "d.cook": "Use @./e.\n",
            "e.cook": "Add @salt{}.\n",
        ])
        defer { try? FileManager.default.removeItem(at: vault) }
        let result = RecipeInliner.inline(source: "Use @./b.\n", relativeTo: vault, maxTotalFiles: 3)
        XCTAssertEqual(result.issues, ["Too many sauces: ./e"])
        // The over-budget ref is left as written, not resolved.
        XCTAssertTrue(result.source.contains("Use @./e."), result.source)
        XCTAssertFalse(result.source.contains("Add @salt"), "e must never be read")
    }

    func testTargetMetadataLinesAreStripped() throws {
        let vault = try makeVault(["a.cook": "Use @./B.\n", "B.cook": hollandaise])
        defer { try? FileManager.default.removeItem(at: vault) }
        let result = RecipeInliner.inline(source: "Use @./B.\n", relativeTo: vault)
        XCTAssertFalse(result.source.contains(">> title"), result.source)
        XCTAssertFalse(result.source.contains("Hollandaise"), "the header must not become prose")
        XCTAssertTrue(result.source.contains("egg yolk"), result.source)
    }

    func testPercentParsing() throws {
        let vault = try makeVault(["B.cook": "Add @salt{}.\n"])
        defer { try? FileManager.default.removeItem(at: vault) }
        func capturedPercent(for source: String) -> Int? {
            let box = PercentBox()
            _ = RecipeInliner.inline(
                source: source,
                relativeTo: vault,
                scaler: { _, percent in box.value = percent; return "X" }
            )
            return box.value
        }
        XCTAssertEqual(capturedPercent(for: "Use @./B{150%g}.\n"), 150)
        XCTAssertEqual(capturedPercent(for: "Use @./B{50%}.\n"), 50)
        XCTAssertNil(capturedPercent(for: "Use @./B.\n"))
        XCTAssertNil(capturedPercent(for: "Use @./B{}.\n"))
        XCTAssertNil(capturedPercent(for: "Use @./B{2}.\n"), "a bare quantity is not a scale this card invents")
    }

    func testScaleFractionForPercent() {
        XCTAssertEqual(OliverClient.fraction(forPercent: 150), "3/2")
        XCTAssertEqual(OliverClient.fraction(forPercent: 50), "1/2")
        XCTAssertEqual(OliverClient.fraction(forPercent: 200), "2")
        XCTAssertEqual(OliverClient.fraction(forPercent: 100), "1")
    }

    // MARK: - Real Oliver

    func testSauceInliningThroughRealOliver() throws {
        let client = try recipeJSONClient()
        let vault = try makeVault([
            "Recipes/risotto.cook": risotto,
            "Recipes/sauces/Hollandaise.cook": hollandaise,
        ])
        defer { try? FileManager.default.removeItem(at: vault) }

        let inlined = RecipeInliner.inline(
            source: risotto,
            relativeTo: vault.appendingPathComponent("Recipes"),
            scaler: { try client.scaleSource($0, percent: $1) }
        )
        XCTAssertTrue(inlined.issues.isEmpty, inlined.issues.joined())

        let one = try client.recipe(inlined.source, scale: .one)
        XCTAssertEqual(one.ingredientIndex.first { $0.name == "egg yolk" }?.quantity, "3", "2 yolks × 150% ref")
        XCTAssertEqual(one.ingredientIndex.first { $0.name == "lemon juice" }?.quantity, "3/2", "1 tbsp × 150% ref")

        // The view scale compounds the ref scale for the sauce's amounts.
        let doubled = try client.recipe(inlined.source, scale: .two)
        XCTAssertEqual(doubled.ingredientIndex.first { $0.name == "egg yolk" }?.quantity, "6", "2 × 150% × 2×")
        XCTAssertEqual(doubled.ingredientIndex.first { $0.name == "lemon juice" }?.quantity, "3", "1 tbsp × 150% × 2×")
        XCTAssertNotNil(doubled.ingredientIndex.first { $0.name == "butter" })
    }

    /// The card's gate, on the checked-in fixture: `Recipes/risotto.cook`
    /// references `./sauces/Hollandaise.cook`, and Read shows butter and
    /// yolks. The file on disk still says `@./sauces/…`.
    func testSampleRisottoInlinesTheSauce() throws {
        let client = try recipeJSONClient()
        let url = d3SampleRisottoURL()
        let before = try Data(contentsOf: url)
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(source.contains("@./sauces/Hollandaise{150%g}"), "the fixture must reference the sauce")

        let inlined = RecipeInliner.inline(
            source: source,
            relativeTo: url.deletingLastPathComponent(),
            scaler: { try client.scaleSource($0, percent: $1) }
        )
        XCTAssertTrue(inlined.issues.isEmpty, inlined.issues.joined())

        let recipe = try client.recipe(inlined.source, scale: .one)
        let names = recipe.ingredientIndex.map(\.name)
        XCTAssertTrue(names.contains("egg yolk"), names.joined(separator: ", "))
        XCTAssertTrue(names.contains("lemon juice"), names.joined(separator: ", "))
        XCTAssertTrue(names.contains("butter"), names.joined(separator: ", "))
        // The walk never rewrites the recipe file.
        XCTAssertEqual(try Data(contentsOf: url), before)
        XCTAssertTrue(inlined.source.contains("@arborio rice{300%g}"), "risotto's own amounts stay untouched")
    }
}

private func recipeJSONClient() throws -> OliverClient {
    guard let url = OliverLocator.resolveRecipeJSON() else {
        throw XCTSkip("Oliver serialize --json is not available")
    }
    return OliverClient(binaryURL: url)
}

private func d3SampleRisottoURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Examples/sample-vault/Recipes/risotto.cook")
}

/// Reference box so a @Sendable scaler can hand back the percent it saw.
private final class PercentBox: @unchecked Sendable {
    var value: Int?
}

private extension RecipeInlinerTests {
    func makeVault(_ files: [String: String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("banal-d3-\(UUID().uuidString)", isDirectory: true)
        for (relative, contents) in files {
            let url = root.appendingPathComponent(relative)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(contents.utf8).write(to: url)
        }
        return root
    }
}
