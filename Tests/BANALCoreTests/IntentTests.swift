import AppIntents
import XCTest
@testable import BANALCore

@MainActor
final class IntentTests: XCTestCase {
    private var tempVaultURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempVaultURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "banal-intent-tests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: tempVaultURL, withIntermediateDirectories: true)
        IntentVaultResolver.setTestVaultURL(tempVaultURL)
    }

    override func tearDown() async throws {
        IntentVaultResolver.setTestVaultURL(nil)
        if let tempVaultURL {
            try? FileManager.default.removeItem(at: tempVaultURL)
        }
        try await super.tearDown()
    }

    func testNewNoteIntentCreatesMarkdownFile() async throws {
        let intent = NewNoteIntent(title: "Meeting Notes", body: "Discuss roadmap\n- Item 1\n- Item 2", folder: nil)
        let result = try await intent.perform()
        XCTAssertEqual(result.value?.title, "Meeting Notes")
        XCTAssertEqual(result.value?.language, "markdown")

        let store = try IntentVaultResolver.loadStore()
        let note = store.notes.first(where: { $0.title == "Meeting Notes" })
        XCTAssertNotNil(note)
        XCTAssertEqual(note?.displayTitle, "Meeting Notes")
        XCTAssertTrue(note?.body.contains("Discuss roadmap") == true)
        if let note {
            XCTAssertTrue(FileManager.default.fileExists(atPath: note.fileURL.path))
            XCTAssertEqual(note.fileURL.pathExtension, "md")
        }
    }

    func testNewRecipeIntentCreatesCookFile() async throws {
        let recipeBody = "Add @olive oil{2%tbsp} to pan.\nAdd @garlic{2%cloves}.\n"
        let intent = NewRecipeIntent(title: "Garlic Confit", body: recipeBody, folder: "Recipes")
        let result = try await intent.perform()
        XCTAssertEqual(result.value?.title, "Garlic Confit")
        XCTAssertEqual(result.value?.language, "cooklang")
        XCTAssertEqual(result.value?.folder, "Recipes")

        let store = try IntentVaultResolver.loadStore()
        let note = store.notes.first(where: { $0.title == "Garlic Confit" })
        XCTAssertNotNil(note)
        XCTAssertEqual(note?.displayTitle, "Garlic Confit")
        XCTAssertEqual(note?.language, .cooklang)
        if let note {
            XCTAssertTrue(FileManager.default.fileExists(atPath: note.fileURL.path))
            XCTAssertEqual(note.fileURL.pathExtension, "cook")

            let diskContent = try String(contentsOf: note.fileURL, encoding: .utf8)
            XCTAssertTrue(diskContent.contains(">> title: Garlic Confit"))
            XCTAssertTrue(diskContent.contains("@olive oil{2%tbsp}"))
        }
    }

    func testTakeNoteIntentWritesInboxNote() async throws {
        let intent = TakeNoteIntent(text: "Remember to buy milk on the way home")
        let result = try await intent.perform()
        XCTAssertEqual(result.value?.folder, "Inbox")

        let store = try IntentVaultResolver.loadStore()
        let note = store.notes.first(where: { $0.folder == "Inbox" })
        XCTAssertNotNil(note)
        XCTAssertEqual(note?.folder, "Inbox")
        XCTAssertTrue(note?.body.contains("Remember to buy milk") == true)
        if let note {
            XCTAssertTrue(FileManager.default.fileExists(atPath: note.fileURL.path))
        }
    }

    func testSearchNotesIntentReturnsMatches() async throws {
        let store = try IntentVaultResolver.loadStore()
        try store.createNote(title: "Grocery List", body: "Apples, Bananas, Oranges", folder: "Inbox", language: .markdown)
        try store.createNote(title: "Risotto", body: "Add @saffron{1%pinch} and @rice{300%g}.", folder: "Recipes", language: .cooklang)
        try store.createNote(title: "Work Ideas", body: "Brainstorming new features", folder: nil, language: .markdown)

        let searchSaffron = SearchNotesIntent(query: "saffron")
        let saffronResults = try await searchSaffron.perform()
        XCTAssertEqual(saffronResults.value?.count, 1)
        XCTAssertEqual(saffronResults.value?.first?.title, "Risotto")

        let searchGrocery = SearchNotesIntent(query: "Apples")
        let groceryResults = try await searchGrocery.perform()
        XCTAssertEqual(groceryResults.value?.count, 1)
        XCTAssertEqual(groceryResults.value?.first?.title, "Grocery List")

        let searchNone = SearchNotesIntent(query: "nonexistent-keyword-xyz")
        let noneResults = try await searchNone.perform()
        XCTAssertEqual(noneResults.value?.count, 0)
    }

    func testOpenNotesFolderIntentResolves() async throws {
        let intent = OpenNotesFolderIntent()
        let result = try await intent.perform()
        XCTAssertNotNil(result)
    }
}
