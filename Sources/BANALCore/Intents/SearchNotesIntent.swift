import AppIntents
import Foundation

public struct SearchNotesIntent: AppIntent {
    public static let title: LocalizedStringResource = "Search Notes"
    public static let description = IntentDescription("Search notes in BANAL by title, body, or ingredients.")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Query")
    public var query: String

    public init() {
        self.query = ""
    }

    public init(query: String) {
        self.query = query
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<[NoteEntity]> {
        let queryParam = self.query

        let entities = try await MainActor.run {
            let store = try IntentVaultResolver.loadStore()
            let matches = store.notes(matching: .all, query: queryParam)
            return matches.map(NoteEntity.init(from:))
        }

        let count = entities.count
        let dialogText = count == 1 ? "Found 1 matching note." : "Found \(count) matching notes."
        return .result(
            value: entities,
            dialog: IntentDialog(stringLiteral: dialogText)
        )
    }
}
