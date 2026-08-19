import Foundation

/// Whether launch should open the notes folder or show the picker.
public enum NotesFolderAccess: Equatable, Sendable {
    case firstRun
    case ready(URL)
    case missing(URL)

    public static func resolve(remembered: URL?, fileManager: FileManager = .default) -> NotesFolderAccess {
        guard let remembered else { return .firstRun }
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: remembered.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return .ready(remembered)
        }
        return .missing(remembered)
    }

    /// Launch pipeline: restore the bookmark, then classify. Never creates a folder.
    public static func resolveRemembered(
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> NotesFolderAccess {
        resolve(
            remembered: VaultBookmark.restore(defaults: defaults, environment: environment),
            fileManager: fileManager
        )
    }
}
