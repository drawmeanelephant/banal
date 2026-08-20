import AppIntents
import BANALCore
import BANALPublisher

public struct BANALShortcutsProvider: AppShortcutsProvider {
    public static let shortcutTileColor: ShortcutTileColor = .navy

    @AppShortcutsBuilder
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewNoteIntent(),
            phrases: [
                "New note in \(.applicationName)",
                "Create note in \(.applicationName)"
            ],
            shortTitle: "New Note",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: TakeNoteIntent(),
            phrases: [
                "Take a note in \(.applicationName)",
                "Take note in \(.applicationName)"
            ],
            shortTitle: "Take a Note",
            systemImageName: "note.text.badge.plus"
        )
        AppShortcut(
            intent: NewRecipeIntent(),
            phrases: [
                "New recipe in \(.applicationName)",
                "Create recipe in \(.applicationName)"
            ],
            shortTitle: "New Recipe",
            systemImageName: "fork.knife"
        )
        AppShortcut(
            intent: SearchNotesIntent(),
            phrases: [
                "Search notes in \(.applicationName)",
                "Find notes in \(.applicationName)"
            ],
            shortTitle: "Search Notes",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: PublishSiteIntent(),
            phrases: [
                "Publish notes in \(.applicationName)",
                "Publish site in \(.applicationName)"
            ],
            shortTitle: "Publish Notes",
            systemImageName: "globe"
        )
        AppShortcut(
            intent: OpenNotesFolderIntent(),
            phrases: [
                "Open notes folder in \(.applicationName)",
                "Open notes in \(.applicationName)"
            ],
            shortTitle: "Open Notes Folder",
            systemImageName: "folder"
        )
    }
}
