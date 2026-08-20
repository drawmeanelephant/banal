import AppIntents
import AppKit
import Foundation

public struct OpenNotesFolderIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Notes Folder"
    public static let description = IntentDescription("Open the active notes folder in Finder.")
    public static let openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try await MainActor.run {
            let vaultURL = try IntentVaultResolver.resolveVaultURL()
            NSWorkspace.shared.activateFileViewerSelecting([vaultURL])
        }
        return .result(dialog: IntentDialog(stringLiteral: "Opened notes folder in Finder."))
    }
}
