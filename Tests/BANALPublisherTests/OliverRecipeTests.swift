import XCTest
@testable import BANALPublisher

final class OliverRecipeTests: XCTestCase {
    func testDecodesEmptyRecipe() throws {
        let recipe = try OliverRecipe.decode(from: #"{"frontmatter":null,"metadata":null,"blocks":[]}"#)
        XCTAssertTrue(recipe.blocks.isEmpty)
        XCTAssertTrue(recipe.ingredientIndex.isEmpty)
        XCTAssertTrue(recipe.cookwareIndex.isEmpty)
    }

    func testDecodesFixtureAndIndexesFirstSeen() throws {
        let recipe = try OliverRecipe.decode(from: fixtureJSON)
        XCTAssertEqual(
            recipe.ingredientIndex.map(\.name),
            ["stock", "arborio rice", "olive oil", "parmesan", "butter", "salt", "pepper"]
        )
        XCTAssertEqual(recipe.ingredientIndex[0].quantity, "1")
        XCTAssertEqual(recipe.ingredientIndex[0].units, "l")
        XCTAssertEqual(recipe.ingredientIndex[1].quantity, "300")
        XCTAssertEqual(recipe.ingredientIndex[1].units, "g")
        XCTAssertEqual(recipe.ingredientIndex[3].preparation, "grated")
        XCTAssertEqual(recipe.cookwareIndex.map(\.name), ["saucepan", "wide pan"])

        let note = recipe.blocks.first { if case .note = $0 { return true }; return false }
        guard case .note(let text) = note else {
            return XCTFail("expected a note")
        }
        XCTAssertEqual(text, "Stir often so it does not catch.")
    }

    func testIngredientIndexKeepsFirstQuantity() throws {
        let recipe = try OliverRecipe.decode(from: fixtureJSON)
        let stock = recipe.ingredientIndex.first { $0.name == "stock" }
        XCTAssertEqual(stock?.quantity, "1")
        XCTAssertEqual(stock?.units, "l")
    }

    func testStepInlineIncludesAmounts() throws {
        let recipe = try OliverRecipe.decode(from: fixtureJSON)
        guard case .step(let parts) = recipe.blocks[1] else {
            return XCTFail("expected toast step")
        }
        let prose = parts.map(\.inlineText).joined()
        XCTAssertTrue(prose.contains("300 g arborio rice"), prose)
        XCTAssertTrue(prose.contains("2 tbsp olive oil"), prose)
        XCTAssertTrue(prose.contains("wide pan"), prose)
    }

    func testScaleFactorArguments() {
        XCTAssertEqual(RecipeScale.half.factorArgument, "1/2")
        XCTAssertEqual(RecipeScale.one.factorArgument, "1")
        XCTAssertEqual(RecipeScale.two.factorArgument, "2")
        XCTAssertEqual(RecipeScale.three.factorArgument, "3")
    }

    func testMissingBinaryThrows() {
        let url = URL(fileURLWithPath: "/tmp/banal-missing-oliver-\(UUID().uuidString)")
        XCTAssertThrowsError(try OliverClient(binaryURL: url).recipe("Add @salt{}.\n")) { error in
            XCTAssertEqual(error as? OliverError, .missingBinary)
        }
    }

    func testRecipeJSONWhenOliverSupportsIt() throws {
        let client = try recipeJSONClient()
        let one = try client.recipe(risottoSource)
        XCTAssertEqual(one.ingredientIndex.first { $0.name == "arborio rice" }?.quantity, "300")
        let timer = one.blocks.compactMap { block -> OliverTimer? in
            guard case .step(let parts) = block else { return nil }
            for part in parts {
                if case .timer(let timer) = part { return timer }
            }
            return nil
        }.first
        XCTAssertEqual(timer?.quantity, "18")

        let doubled = try client.recipe(risottoSource, scale: .two)
        XCTAssertEqual(doubled.ingredientIndex.first { $0.name == "arborio rice" }?.quantity, "600")
        XCTAssertEqual(doubled.ingredientIndex.first { $0.name == "stock" }?.quantity, "2")
        XCTAssertEqual(doubled.ingredientIndex.first { $0.name == "olive oil" }?.quantity, "4")
        XCTAssertEqual(doubled.ingredientIndex.first { $0.name == "parmesan" }?.quantity, "100")
        let doubledTimer = doubled.blocks.compactMap { block -> OliverTimer? in
            guard case .step(let parts) = block else { return nil }
            for part in parts {
                if case .timer(let timer) = part { return timer }
            }
            return nil
        }.first
        XCTAssertEqual(doubledTimer?.quantity, "18")
        XCTAssertEqual(doubled.cookwareIndex.map(\.name), ["saucepan", "wide pan"])

        let stillOne = try client.recipe(risottoSource, scale: .one)
        XCTAssertEqual(stillOne.ingredientIndex.first { $0.name == "arborio rice" }?.quantity, "300")
        XCTAssertTrue(risottoSource.contains("@arborio rice{300%g}"))
    }

    func testHalfScaleWhenOliverSupportsIt() throws {
        let client = try recipeJSONClient()
        let half = try client.recipe(risottoSource, scale: .half)
        XCTAssertEqual(half.ingredientIndex.first { $0.name == "arborio rice" }?.quantity, "150")
        XCTAssertEqual(half.ingredientIndex.first { $0.name == "stock" }?.quantity, "1/2")
    }
}

private func recipeJSONClient() throws -> OliverClient {
    guard let url = OliverLocator.resolveRecipeJSON() else {
        throw XCTSkip("Oliver serialize --json is not available")
    }
    return OliverClient(binaryURL: url)
}

private let risottoSource = """
Warm @stock{1%l} in #saucepan{}.

Toast @arborio rice{300%g} in #wide pan{} with @olive oil{2%tbsp} until translucent.

Add the @stock{} a ladle at a time, stirring, for ~{18%minutes}.

> Stir often so it does not catch.

Fold in @parmesan{50%g}(grated) and @butter{40%g}.

Season with @salt{} and @pepper{}.
"""

/// Checked-in dump of `oliver serialize --from cooklang --json` for `risottoSource`.
private let fixtureJSON = """
{"frontmatter":null,"metadata":null,"blocks":[{"kind":"step","span":{"start":0,"end":32},"parts":[{"kind":"text","text":"Warm ","span":{"start":0,"end":5}},{"kind":"ingredient","name":"stock","name_span":{"start":6,"end":11},"quantity":"1","quantity_span":{"start":12,"end":13},"units":"l","units_span":{"start":14,"end":15},"preparation":null,"span":{"start":5,"end":16}},{"kind":"text","text":" in ","span":{"start":16,"end":20}},{"kind":"cookware","name":"saucepan","name_span":{"start":21,"end":29},"quantity":"","quantity_span":{"start":30,"end":30},"span":{"start":20,"end":31}},{"kind":"text","text":".","span":{"start":31,"end":32}}]},{"kind":"step","span":{"start":34,"end":118},"parts":[{"kind":"text","text":"Toast ","span":{"start":34,"end":40}},{"kind":"ingredient","name":"arborio rice","name_span":{"start":41,"end":53},"quantity":"300","quantity_span":{"start":54,"end":57},"units":"g","units_span":{"start":58,"end":59},"preparation":null,"span":{"start":40,"end":60}},{"kind":"text","text":" in ","span":{"start":60,"end":64}},{"kind":"cookware","name":"wide pan","name_span":{"start":65,"end":73},"quantity":"","quantity_span":{"start":74,"end":74},"span":{"start":64,"end":75}},{"kind":"text","text":" with ","span":{"start":75,"end":81}},{"kind":"ingredient","name":"olive oil","name_span":{"start":82,"end":91},"quantity":"2","quantity_span":{"start":92,"end":93},"units":"tbsp","units_span":{"start":94,"end":98},"preparation":null,"span":{"start":81,"end":99}},{"kind":"text","text":" until translucent.","span":{"start":99,"end":118}}]},{"kind":"step","span":{"start":120,"end":184},"parts":[{"kind":"text","text":"Add the ","span":{"start":120,"end":128}},{"kind":"ingredient","name":"stock","name_span":{"start":129,"end":134},"quantity":"","quantity_span":{"start":135,"end":135},"units":"","units_span":{"start":135,"end":135},"preparation":null,"span":{"start":128,"end":136}},{"kind":"text","text":" a ladle at a time, stirring, for ","span":{"start":136,"end":170}},{"kind":"timer","name":"","name_span":{"start":171,"end":171},"quantity":"18","quantity_span":{"start":172,"end":174},"units":"minutes","units_span":{"start":175,"end":182},"span":{"start":170,"end":183}},{"kind":"text","text":".","span":{"start":183,"end":184}}]},{"kind":"note","text":"Stir often so it does not catch.","span":{"start":186,"end":220}},{"kind":"step","span":{"start":222,"end":272},"parts":[{"kind":"text","text":"Fold in ","span":{"start":222,"end":230}},{"kind":"ingredient","name":"parmesan","name_span":{"start":231,"end":239},"quantity":"50","quantity_span":{"start":240,"end":242},"units":"g","units_span":{"start":243,"end":244},"preparation":"grated","span":{"start":230,"end":253}},{"kind":"text","text":" and ","span":{"start":253,"end":258}},{"kind":"ingredient","name":"butter","name_span":{"start":259,"end":265},"quantity":"40","quantity_span":{"start":266,"end":268},"units":"g","units_span":{"start":269,"end":270},"preparation":null,"span":{"start":258,"end":271}},{"kind":"text","text":".","span":{"start":271,"end":272}}]},{"kind":"step","span":{"start":274,"end":308},"parts":[{"kind":"text","text":"Season with ","span":{"start":274,"end":286}},{"kind":"ingredient","name":"salt","name_span":{"start":287,"end":291},"quantity":"","quantity_span":{"start":292,"end":292},"units":"","units_span":{"start":292,"end":292},"preparation":null,"span":{"start":286,"end":293}},{"kind":"text","text":" and ","span":{"start":293,"end":298}},{"kind":"ingredient","name":"pepper","name_span":{"start":299,"end":305},"quantity":"","quantity_span":{"start":306,"end":306},"units":"","units_span":{"start":306,"end":306},"preparation":null,"span":{"start":298,"end":307}},{"kind":"text","text":".","span":{"start":307,"end":308}}]}]}
"""
