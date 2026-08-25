import BANALCore
import Foundation

/// On-device enrichment: improve markup, suggest a title. Explicit user
/// action only; undo lives in the editor's undo manager.
@MainActor
public final class EnrichmentController {
    private let client: any EnrichmentClient

    public init(client: any EnrichmentClient = CompositeEnricher()) {
        self.client = client
    }

    /// Returns the enriched markup, or nil when no enrichment is available.
    public func enrichMarkup(_ source: String) async throws -> String? {
        try await client.enrichMarkup(source)
    }

    /// Returns a suggested title, or nil when none is available.
    public func suggestTitle(_ source: String) async throws -> String? {
        try await client.suggestTitle(source)
    }
}
