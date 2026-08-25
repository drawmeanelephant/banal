import BANALCore
import Combine
import Foundation

/// Folder flows: the sidebar's new-folder/rename alert state, and the
/// store operations behind them. Selection and filter reactions stay
/// with the coordinator; this type owns the dialog lifecycle and the
/// fiddly drop-resolution rules.
@MainActor
public final class FolderController: ObservableObject {
    @Published public var nameDraft = ""
    @Published public var isCreating = false
    @Published public var isRenaming = false
    public private(set) var renamingID: String?

    public init() {}

    // MARK: - New folder

    public func beginNewFolder(defaultName: String = "Untitled Folder") {
        nameDraft = defaultName
        isCreating = true
    }

    /// Create the drafted folder under `parent`. Throws on failure after
    /// clearing the alert state; the coordinator reacts to success.
    public func confirmNewFolder(store: NoteStore, parent: String?) throws -> FolderNode {
        isCreating = false
        let name = nameDraft
        nameDraft = ""
        return try store.createFolder(name: name, parent: parent)
    }

    // MARK: - Rename

    public func beginRename(_ id: String) {
        renamingID = id
        nameDraft = (id as NSString).lastPathComponent
        isRenaming = true
    }

    /// Rename the folder being edited. Returns the renamed node plus its
    /// previous id so the coordinator can remap selection and filter;
    /// nil when no rename was in flight.
    public func confirmRename(store: NoteStore) throws -> (renamed: FolderNode, previousID: String)? {
        isRenaming = false
        let name = nameDraft
        guard let id = renamingID else {
            nameDraft = ""
            return nil
        }
        renamingID = nil
        nameDraft = ""
        let renamed = try store.renameFolder(id: id, to: name)
        return (renamed, id)
    }

    // MARK: - Drop resolution

    /// Resolve a dropped identifier to a movable note id: exact store ids
    /// win, then file paths (raw, standardized, or URL-string form). Any
    /// other string passes through untouched — `moveNote` reports why not.
    public static func resolvedMoveTarget(for rawID: String, notes: [Note]) -> String {
        if notes.contains(where: { $0.id == rawID }) {
            return rawID
        }
        if let match = notes.first(where: {
            $0.fileURL.path == rawID ||
                $0.fileURL.standardizedFileURL.path == URL(fileURLWithPath: rawID).standardizedFileURL.path ||
                $0.fileURL.absoluteString == rawID ||
                $0.id == rawID
        }) {
            return match.id
        }
        return rawID
    }

    /// Resolve a dragged file URL: an existing note's file moves by id,
    /// a vault-relative path moves by relative id, anything else falls
    /// back to the absolute path (an external import-by-path attempt).
    public static func resolvedMoveTarget(for url: URL, vaultRoot: URL, notes: [Note]) -> String {
        if let match = notes.first(where: {
            $0.fileURL.standardizedFileURL == url.standardizedFileURL ||
                $0.fileURL.path == url.path
        }) {
            return match.id
        }
        let vaultPath = vaultRoot.standardizedFileURL.path
        let itemPath = url.standardizedFileURL.path
        if itemPath.hasPrefix(vaultPath) {
            let relative = String(itemPath.dropFirst(vaultPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return relative
        }
        return url.path
    }
}
