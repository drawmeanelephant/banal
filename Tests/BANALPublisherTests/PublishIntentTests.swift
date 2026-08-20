import AppIntents
import BANALCore
import XCTest
@testable import BANALPublisher

final class PublishIntentTests: XCTestCase {
    @MainActor
    private func makeVault() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "banal-pub-intent-tests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        IntentVaultResolver.setTestVaultURL(url)
        return url
    }

    @MainActor
    func testPublishSiteIntentWithoutPublishedNotes() async throws {
        let vaultURL = try makeVault()
        defer {
            IntentVaultResolver.setTestVaultURL(nil)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let intent = PublishSiteIntent()
        let result = try await intent.perform()
        XCTAssertEqual(result.value, "Nothing published.")
    }

    @MainActor
    func testPublishSiteIntentWithPublishedNote() async throws {
        let vaultURL = try makeVault()
        defer {
            IntentVaultResolver.setTestVaultURL(nil)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        let store = try IntentVaultResolver.loadStore()
        var note = try store.createNote(title: "Published Note", body: "Hello published world.", folder: nil, language: .markdown)
        note.published = true
        store.update(note, debounce: false)
        store.flush()
        XCTAssertEqual(store.notes.filter(\.published).count, 1)

        let intent = PublishSiteIntent()
        let result = try await intent.perform()
        XCTAssertTrue(result.value?.contains("Published 1 note") == true)

        let publishDir = vaultURL.appendingPathComponent(".publish")
        XCTAssertTrue(FileManager.default.fileExists(atPath: publishDir.appendingPathComponent("index.html").path))
    }
}
