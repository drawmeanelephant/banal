import AppIntents
import Foundation

public struct TakeNoteIntent: AppIntent {
    public static let title: LocalizedStringResource = "Take a Note"
    public static let description = IntentDescription("Quickly capture a note in BANAL.")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Text")
    public var text: String

    @Parameter(title: "Folder")
    public var folder: String?

    public init() {
        self.text = ""
    }

    public init(text: String, folder: String? = nil) {
        self.text = text
        self.folder = folder
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<NoteEntity> {
        let textParam = self.text
        let folderParam = self.folder

        let (entity, targetFolder) = try await MainActor.run {
            let store = try IntentVaultResolver.loadStore()
            let destination = folderParam ?? "Inbox"

            let trimmed = textParam.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedTitle = inferredTitle(from: trimmed) ?? "Note"
            let noteBody = trimmed.isEmpty ? "\n" : trimmed

            let note = try store.createNote(
                title: resolvedTitle,
                body: noteBody,
                folder: destination,
                language: .markdown
            )
            return (NoteEntity(from: note), destination)
        }

        return .result(
            value: entity,
            dialog: IntentDialog(stringLiteral: "Saved note to \(targetFolder).")
        )
    }
}
