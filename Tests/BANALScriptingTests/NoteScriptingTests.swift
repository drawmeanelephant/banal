import XCTest
@testable import BANALCore
@testable import BANALScripting

/// The scripted surface behaves like the App Intents: a fresh store per call,
/// disk is truth, and every write lands in ordinary files.
final class NoteScriptingTests: XCTestCase {
    private var vaultURL: URL!

    override func setUpWithError() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("banal-scripting-tests-\(UUID().uuidString)", isDirectory: true)
        try VaultBootstrap.prepare(VaultConfiguration(rootURL: url))
        try MainActor.assumeIsolated { IntentVaultResolver.setTestVaultURL(url) }
        vaultURL = url
    }

    override func tearDownWithError() throws {
        try MainActor.assumeIsolated { IntentVaultResolver.setTestVaultURL(nil) }
        try? FileManager.default.removeItem(at: vaultURL)
    }

    @MainActor
    func testListAndReadNotes() throws {
        try Data("---\ntitle: Published Note\ncreated: 2026-08-25T10:00:00Z\nupdated: 2026-08-25T10:00:00Z\npublished: true\n---\n\nHello scripted.\n".utf8)
            .write(to: vaultURL.appendingPathComponent("Published Note.md"))

        let notes = try NoteScripting.listNotes()
        XCTAssertEqual(notes.count, 2) // Welcome + the one above

        let record = try NoteScripting.readNote(id: "Published Note.md")
        XCTAssertEqual(record["title"] as? String, "Published Note")
        XCTAssertEqual(record["published"] as? Bool, true)
        XCTAssertTrue((record["body"] as? String)?.contains("Hello scripted.") == true)

        XCTAssertThrowsError(
            try NoteScripting.readNote(id: "Nope.md")
        ) { error in
            XCTAssertTrue("\(error)".contains("No note"))
        }
    }

    @MainActor
    func testCreateNoteWritesAPlainNamedFile() throws {
        let record = try NoteScripting.createNote(
            title: "Tom Kha Gai",
            body: "Warm the coconut milk.",
            folder: "Recipes",
            language: "markdown",
            published: true
        )
        XCTAssertEqual(record["id"] as? String, "Recipes/Tom Kha Gai.md")
        XCTAssertEqual(record["published"] as? Bool, true)

        let file = try String(contentsOf: vaultURL.appendingPathComponent("Recipes/Tom Kha Gai.md"), encoding: .utf8)
        XCTAssertTrue(file.contains("published: true"), file)
        XCTAssertTrue(file.contains("Warm the coconut milk."), file)
    }

    @MainActor
    func testCreateNoteRejectsUnknownLanguage() {
        XCTAssertThrowsError(
            try NoteScripting.createNote(title: "X", body: nil, folder: nil, language: "org-mode", published: false)
        ) { error in
            XCTAssertTrue("\(error)".contains("markdown, textile, or cooklang"))
        }
    }

    @MainActor
    func testUpdateBodyAndSetPublishedRoundTripToDisk() throws {
        let created = try NoteScripting.createNote(title: "Draft", body: "First.", folder: nil, language: nil, published: false)
        let id = created["id"] as! String

        _ = try NoteScripting.updateNoteBody(id: id, body: "Second.")
        _ = try NoteScripting.setPublished(true, id: id)

        let file = try String(contentsOf: vaultURL.appendingPathComponent(id), encoding: .utf8)
        XCTAssertTrue(file.contains("Second."), file)
        XCTAssertTrue(file.contains("published: true"), file)

        let reread = try NoteScripting.readNote(id: id)
        XCTAssertEqual(reread["published"] as? Bool, true)
        XCTAssertTrue((reread["body"] as? String)?.contains("Second.") == true)
    }

    @MainActor
    func testPublishSiteReturnsStatusCopy() throws {
        _ = try NoteScripting.createNote(title: "Solo", body: "One page.", folder: nil, language: nil, published: true)
        let status = try NoteScripting.publishSite()
        XCTAssertTrue(status.hasPrefix("Published 1 note"), status)
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.appendingPathComponent(".publish/index.html").path))
    }
}
