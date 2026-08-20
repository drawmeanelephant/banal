import AppIntents
import Foundation

public struct NewNoteIntent: AppIntent {
    public static let title: LocalizedStringResource = "New Note"
    public static let description = IntentDescription("Create a new note in BANAL.")
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
            let prefs = AppPreferencesStore.load()
            let targetFolder = folderParam ?? prefs.folderForNewNote(selected: .all)

            let trimmedTitle = titleParam?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedTitle: String
            if let trimmedTitle, !trimmedTitle.isEmpty {
                resolvedTitle = trimmedTitle
            } else if let bodyParam, let inferred = inferredTitle(from: bodyParam) {
                resolvedTitle = inferred
            } else {
                resolvedTitle = "Untitled"
            }

            let noteBody = bodyParam ?? "\n"
            let note = try store.createNote(
                title: resolvedTitle,
                body: noteBody,
                folder: targetFolder,
                language: .markdown
            )
            return (NoteEntity(from: note), note.displayTitle)
        }

        return .result(
            value: entity,
            dialog: IntentDialog(stringLiteral: "Created note \"\(displayTitle)\".")
        )
    }
}
