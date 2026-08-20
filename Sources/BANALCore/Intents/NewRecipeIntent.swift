import AppIntents
import Foundation

public struct NewRecipeIntent: AppIntent {
    public static let title: LocalizedStringResource = "New Recipe"
    public static let description = IntentDescription("Create a new recipe in BANAL.")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Title")
    public var title: String?

    @Parameter(title: "Body")
    public var body: String?

    @Parameter(title: "Folder")
    public var folder: String?

    public init() {}

    public init(title: String? = nil, body: String? = nil, folder: String? = nil) {
        self.title = title
        self.body = body
        self.folder = folder
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<NoteEntity> {
        let titleParam = self.title
        let bodyParam = self.body
        let folderParam = self.folder

        let (entity, displayTitle) = try await MainActor.run {
            let store = try IntentVaultResolver.loadStore()
            let targetFolder = folderParam ?? "Recipes"

            let trimmedTitle = titleParam?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedTitle = (trimmedTitle?.isEmpty == false) ? trimmedTitle! : "Untitled Recipe"
            let noteBody = bodyParam ?? CooklangStub.body

            let note = try store.createNote(
                title: resolvedTitle,
                body: noteBody,
                folder: targetFolder,
                language: .cooklang
            )
            return (NoteEntity(from: note), note.displayTitle)
        }

        return .result(
            value: entity,
            dialog: IntentDialog(stringLiteral: "Created recipe \"\(displayTitle)\".")
        )
    }
}
