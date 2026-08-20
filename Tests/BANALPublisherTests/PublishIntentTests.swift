import AppIntents
import BANALCore
import XCTest
@testable import BANALPublisher

@MainActor
final class PublishIntentTests: XCTestCase {
    private var tempVaultURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempVaultURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "banal-pub-intent-tests-\(UUID().uuidString)",
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

    func testPublishSiteIntentWithoutPublishedNotes() async throws {
        let intent = PublishSiteIntent()
        let result = try await intent.perform()
        XCTAssertEqual(result.value, "Nothing published.")
    }

    func testPublishSiteIntentWithPublishedNote() async throws {
        let store = try IntentVaultResolver.loadStore()
        var note = try store.createNote(title: "Published Note", body: "Hello published world.", folder: nil, language: .markdown)
        note.published = true
        store.update(note, debounce: false)
        store.flush()
        XCTAssertEqual(store.notes.filter(\.published).count, 1)

        let intent = PublishSiteIntent()
        let result = try await intent.perform()
        XCTAssertTrue(result.value?.contains("Published 1 note") == true)

        let publishDir = tempVaultURL.appendingPathComponent(".publish")
        XCTAssertTrue(FileManager.default.fileExists(atPath: publishDir.appendingPathComponent("index.html").path))
    }
}
