import BANALAppModel
import BANALCore
import XCTest

@MainActor
final class RecipeSessionTests: XCTestCase {
    func testAskWithoutOliverReportsMissingBinary() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let context = ControllerContext(vault: vault)
        _ = try context.store.createNote(title: "Risotto", language: .cooklang)
        let note = try XCTUnwrap(context.store.notes.first)
        context.stubSelectedID = note.id
        context.stubViewMode = .read

        let session = RecipeSession()
        session.context = context
        session.askOliverForRecipe()

        XCTAssertNil(session.oliverRecipe)
        XCTAssertEqual(session.recipeError, "This recipe needs Oliver.")
        XCTAssertEqual(session.recipeIssues, [])
    }

    func testAskOutsideReadOrCooklangClearsInsteadOfErroring() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let context = ControllerContext(vault: vault)
        _ = try context.store.createNote(title: "Prose", body: "Plain markdown.")
        context.stubSelectedID = context.store.notes.first?.id
        context.stubViewMode = .read

        let session = RecipeSession()
        session.context = context
        session.recipeError = "stale"
        session.askOliverForRecipe()

        XCTAssertNil(session.recipeError, "non-recipe notes never show recipe errors")
        XCTAssertNil(session.oliverRecipe)

        context.stubViewMode = .edit
        session.askOliverForRecipe()
        XCTAssertNil(session.recipeError)
    }

    func testClearRecipeResetsAllPublishedState() {
        let session = RecipeSession()
        session.clearRecipe()
        XCTAssertNil(session.oliverRecipe)
        XCTAssertNil(session.recipeError)
        XCTAssertEqual(session.recipeIssues, [])
    }

    func testSaveScaledCopyRequiresScaleAndOliver() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let context = ControllerContext(vault: vault)
        let note = try context.store.createNote(title: "Cookies", language: .cooklang)

        let session = RecipeSession()
        session.context = context

        // Scale 1× is a no-op by definition.
        XCTAssertNil(session.saveScaledCopy(of: note))

        // Without Oliver there is nothing to scale with.
        session.recipeScale = .two
        XCTAssertNil(session.saveScaledCopy(of: note))
        XCTAssertEqual(context.statuses, ["Oliver is not installed."])

        // Non-recipe notes are declined before anything else.
        let prose = try context.store.createNote(title: "Prose", body: "\n")
        session.recipeScale = .one
        XCTAssertNil(session.saveScaledCopy(of: prose))
        XCTAssertEqual(context.statuses.count, 1, "no new status for a non-recipe")
    }

    func testConvertTextileRequiresTextileNoteAndOliver() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let context = ControllerContext(vault: vault)
        let prose = try context.store.createNote(title: "Prose", body: "\n")

        let session = RecipeSession()
        session.context = context

        XCTAssertNil(session.convertTextileToMarkdown(of: prose), "markdown notes are not convertible")

        let textile = try context.store.createNote(title: "Old Page", body: "\nh1. Heading\n", language: .textile)
        XCTAssertNil(session.convertTextileToMarkdown(of: textile))
        XCTAssertEqual(context.statuses, ["Oliver is not installed."])
    }

    func testIngredientCacheRequestsFlowThroughContext() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let context = ControllerContext(vault: vault)
        let note = try context.store.createNote(title: "Soup", language: .cooklang)

        context.cacheIngredients(["onion", "butter"], forNoteID: note.id)
        XCTAssertEqual(context.cachedIngredientCalls.count, 1)
        XCTAssertEqual(context.cachedIngredientCalls.first?.names, ["onion", "butter"])
    }
}
