import BANALAppModel
import BANALCore
import XCTest

@MainActor
final class EnrichmentControllerTests: XCTestCase {
    private struct StubClient: EnrichmentClient {
        var markup: String?
        var title: String?
        var error: Error?

        func enrichMarkup(_ source: String) async throws -> String? {
            if let error { throw error }
            return markup
        }

        func suggestTitle(_ source: String) async throws -> String? {
            if let error { throw error }
            return title
        }
    }

    func testEnrichMarkupReturnsClientResult() async throws {
        let controller = EnrichmentController(client: StubClient(markup: "# Fixed", title: nil))
        let result = try await controller.enrichMarkup("fixed")
        XCTAssertEqual(result, "# Fixed")
    }

    func testUnavailableEnrichmentReturnsNil() async {
        let controller = EnrichmentController(client: StubClient(markup: nil, title: nil))
        let markup = try? await controller.enrichMarkup("anything")
        XCTAssertNil(markup.flatMap { $0 })
        let title = try? await controller.suggestTitle("anything")
        XCTAssertNil(title.flatMap { $0 })
    }
}
