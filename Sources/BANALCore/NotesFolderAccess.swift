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
}
