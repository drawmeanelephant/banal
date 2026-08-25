import BANALCore
import Foundation

/// Notes arriving from outside the vault: Finder opens, Dock drops,
/// the import panel, and Services text. Deduplicates repeated open
/// events and queues arrivals until a vault exists.
@MainActor
public final class ImportController {
    /// Files opened (Finder double-click, Dock drag) before a vault exists.
    /// Imported once `bootstrap()` opens a notes folder.
    private var pendingImports: [URL] = []
    /// The last opened file, for dedupe. `.onOpenURL` and the delegate's
    /// `openFiles` can both fire for one user action; a single action must
    /// never import twice.
    private var lastHandledOpenURL: (url: URL, at: Date)?

    public init() {}

    // MARK: - External opens

    public enum OpenDecision: Equatable {
        /// The file is already a note in the vault; select it.
        case selectExisting(id: String)
        /// The file is inside the vault but is not a note.
        case notANote
        /// The file was copied into the vault; select the new note.
        case imported(id: String)
        /// No vault yet — the URL waits in the pending queue.
        case queued
        /// Import failed.
        case failed(String)
    }

    /// A `.md`, `.textile`, or `.cook` file opened from Finder or dropped
    /// on the Dock icon. Inside the vault: select it. Outside: copy it in.
    /// With no vault open yet, queue it until one opens.
    public func openExternalNote(
        at url: URL,
        vaultRoot: URL?,
        needsVault: Bool,
        importer: (URL) throws -> Note,
        noteExists: (String) -> Bool
    ) -> OpenDecision {
        let standard = url.standardizedFileURL
        if let last = lastHandledOpenURL,
           last.url == standard,
           Date().timeIntervalSince(last.at) < 2 {
            return .queued // duplicate delivery of the same user action
        }
        lastHandledOpenURL = (standard, Date())
        guard !needsVault, let vaultRoot else {
            if !pendingImports.contains(url) {
                pendingImports.append(url)
            }
            return .queued
        }
        return openImportedNote(at: url, vaultRoot: vaultRoot, importer: importer, noteExists: noteExists)
    }

    /// Import (or select) one URL against an open vault.
    public func openImportedNote(
        at url: URL,
        vaultRoot: URL,
        importer: (URL) throws -> Note,
        noteExists: (String) -> Bool
    ) -> OpenDecision {
        let root = vaultRoot.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path == root || path.hasPrefix(root + "/") {
            let id = NoteIdentity.id(for: url, vaultURL: vaultRoot)
            if !id.isEmpty, noteExists(id) {
                return .selectExisting(id: id)
            }
            return .notANote
        }
        do {
            let imported = try importer(url)
            return .imported(id: imported.id)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Imported every queued URL once a vault opened. Returns the
    /// decisions in order for the coordinator to act on.
    public func drainPendingImports(vaultRoot: URL, importer: (URL) throws -> Note, noteExists: (String) -> Bool) -> [OpenDecision] {
        let urls = pendingImports
        pendingImports.removeAll()
        return urls.map { openImportedNote(at: $0, vaultRoot: vaultRoot, importer: importer, noteExists: noteExists) }
    }

    // MARK: - Services text

    public enum ServiceNoteOutcome {
        case created(note: Note, destinationFolder: String?)
        case emptyText
        case failed(String)
    }

    /// Create a note from Services text. The title is inferred from the
    /// first content line when possible; the destination follows the
    /// new-note preference (`nil` folder = vault root).
    public func createServiceNote(
        text: String,
        store: NoteStore,
        destinationFolder: String?
    ) -> ServiceNoteOutcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .emptyText }
        let resolvedTitle = inferredTitle(from: trimmed) ?? "Note"
        do {
            let note = try store.createNote(
                title: resolvedTitle,
                body: trimmed,
                folder: destinationFolder,
                language: .markdown
            )
            return .created(note: note, destinationFolder: destinationFolder)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
