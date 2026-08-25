import BANALAppModel
import BANALCore
import BANALPublisher
import XCTest

@MainActor
final class PublishControllerTests: XCTestCase {
    func testPublishWithoutPublishedNotesReportsQuietly() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        _ = try store.createNote(title: "Draft") // published stays false

        let controller = PublishController()
        var revealed: [URL] = []
        controller.reveal = { revealed.append($0) }

        let outcome = controller.publishSite(vault: store.configuration, notes: store.notes)

        XCTAssertEqual(outcome.message, "Nothing published.")
        XCTAssertNil(outcome.artifact)
        XCTAssertNil(controller.lastResult, "no result is recorded when nothing compiled")
    }

    func testDeployWithoutConnectionStaysLocal() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()

        let controller = PublishController()
        XCTAssertTrue(!controller.canDeploy(vault: store.configuration), "no project name and no token — deploy is unavailable")

        let outcome = controller.deployToCloudflare(vault: store.configuration, notes: store.notes)
        XCTAssertEqual(outcome.message, "Not connected — publishing stays on this Mac.")
    }
}
