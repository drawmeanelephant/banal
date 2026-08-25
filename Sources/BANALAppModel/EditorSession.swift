import BANALCore
import Combine
import Foundation

/// The open note buffer: title, body, tags, publish flag, and the F-9
/// write-back guard (which selection and session a write belongs to).
///
/// The session owns buffer truth. It never touches the store on its own —
/// the coordinator hands it notes in and routes changed notes back into
/// the store, so every path stays observable from one place.
@MainActor
public final class EditorSession: ObservableObject {
    // MARK: - Buffer state (published)

    @Published public var editorText: String = ""
    @Published public var editorTitle: String = ""
    @Published public var editorTags: String = ""
    @Published public var editorPublished: Bool = false
    /// Identity for the open buffer. Changes when the user switches notes,
    /// not when a folder rename or move rewrites the path.
    @Published public private(set) var editorSessionID = UUID()
    /// Currently selected text in the active editor buffer.
    @Published public var selectedText: String = ""
    /// Currently selected range in the active editor buffer.
    @Published public var selectedRange = NSRange(location: 0, length: 0)

    /// View-assigned direct-insertion hook (NSTextView caret). When it
    /// reports `true`, the buffer was already edited at the source.
    public var insertAtCaretHandler: ((String) -> Bool)?

    // MARK: - Write-back guard state (F-9)

    private(set) public var isSuppressed = false
    public private(set) var isDirty = false
    public private(set) var loadedFingerprint = ""
    var loadedExtras: [FrontmatterExtra] = []
    var warnedDiskFingerprint = ""
    /// Which selection and session the open buffer was loaded for. A write
    /// (F-9) must match both: an `onChange` echo from a previous load must
    /// never persist into a note it was not loaded for.
    var loadedForID: String?
    var loadedSessionID = UUID()

    public init() {}

    /// Quiet word and character count for the currently edited note buffer (H-2).
    public var wordCountDescription: String {
        WordCount.count(in: editorText).formattedDescription
    }

    // MARK: - Loading a note into the buffer

    /// Make the buffer belong to this selection and this session; only
    /// writes matching both are allowed afterwards (F-9).
    public func load(from note: Note?, selectedID: String?) {
        editorSessionID = UUID()
        loadedForID = selectedID
        loadedSessionID = editorSessionID
        isSuppressed = true
        editorTitle = note?.title ?? ""
        editorText = note?.body ?? ""
        editorTags = note?.tags.joined(separator: ", ") ?? ""
        editorPublished = note?.published ?? false
        loadedFingerprint = note?.contentFingerprint ?? ""
        loadedExtras = note?.extras ?? []
        isDirty = false
        warnedDiskFingerprint = ""
        selectedText = ""
        selectedRange = NSRange(location: 0, length: 0)
        isSuppressed = false
    }

    // MARK: - Keystroke path

    public struct Change: Equatable {
        public var updated: Note
        public var bodyChanged: Bool
    }

    /// Fold the buffer into `note`. Returns `.none` when nothing differs,
    /// when syncing is suppressed, or when the write does not belong to
    /// the loaded selection + session (F-9).
    public func applyChanges(to note: Note, selectedID: String?) -> Change? {
        guard !isSuppressed,
              selectedID == loadedForID,
              editorSessionID == loadedSessionID else { return nil }
        let parsedTags = Self.parseTags(editorTags)
        if note.title == editorTitle, note.body == editorText, note.tags == parsedTags, note.published == editorPublished {
            return nil
        }
        isDirty = true
        var updated = note
        let bodyChanged = note.body != editorText
        updated.title = editorTitle
        updated.body = editorText
        updated.tags = parsedTags
        updated.published = editorPublished
        return Change(updated: updated, bodyChanged: bodyChanged)
    }

    // MARK: - Persist path

    /// Write the buffer through to disk (`debounce: false`) and settle the
    /// guard fingerprints. Returns the renamed id when the file followed
    /// its retitled note (plain names); the coordinator then re-keys
    /// selection. No-op unless dirty and the guard matches.
    @discardableResult
    public func persist(to id: String, store: NoteStore, writingToolsActive: Bool) -> String? {
        guard !writingToolsActive else { return nil }
        guard isDirty,
              id == loadedForID,
              editorSessionID == loadedSessionID,
              var note = store.note(id: id) else { return nil }
        let previousTitle = note.title
        note.title = editorTitle
        note.body = editorText
        note.tags = Self.parseTags(editorTags)
        note.published = editorPublished
        store.update(note, debounce: false)
        if let saved = store.note(id: id) {
            loadedFingerprint = saved.contentFingerprint
            loadedExtras = saved.extras
            isDirty = false
        }
        // Plain names: once the buffer has settled, let a file that was
        // named after its title follow the retitle. The store declines
        // anything that should not move (empty title, legacy date-stamp
        // names, sanitization-only differences). The session stays put —
        // this is the same buffer, not a note switch.
        if let renamed = (try? store.renameNote(
            id: id,
            previousTitle: previousTitle,
            to: editorTitle
        )) ?? nil {
            loadedForID = renamed.id
            if let settled = store.note(id: renamed.id) {
                loadedFingerprint = settled.contentFingerprint
                loadedExtras = settled.extras
            }
            return renamed.id
        }
        return nil
    }

    // MARK: - External-edit reconciliation support

    /// Whether the buffer is byte-identical to the note currently on disk.
    public func bufferMatchesDisk(_ disk: Note?) -> Bool {
        guard let disk else { return false }
        return disk.title == editorTitle
            && disk.body == editorText
            && disk.tags == Self.parseTags(editorTags)
            && disk.published == editorPublished
            && disk.extras == loadedExtras
    }

    /// `.ignore` outcome: the buffer agrees with disk, so the write-back
    /// guard can relax to the disk state.
    public func acceptIgnoredExternalState(_ disk: Note?) {
        if isDirty, bufferMatchesDisk(disk) {
            isDirty = false
        }
        if let disk {
            loadedFingerprint = disk.contentFingerprint
            loadedExtras = disk.extras
        }
    }

    /// `.keepBuffer` outcome: returns whether this disk fingerprint is new
    /// (the caller shows its "changed on disk" status only once per change).
    public func markDiskChangeWarning(fingerprint: String) -> Bool {
        guard warnedDiskFingerprint != fingerprint else { return false }
        warnedDiskFingerprint = fingerprint
        return true
    }

    /// The selection was destroyed (folder trashed); drop any pending
    /// write-back so it cannot resurrect into a later note.
    public func discardPendingWrite() {
        isDirty = false
    }

    // MARK: - Buffer edits (insertion family)

    /// Insert at the caret via the view handler when one claims the text;
    /// otherwise splice into the buffer at the tracked range. Mutates the
    /// buffer only — the coordinator applies the change to the store.
    public func insertTextAtCaret(_ text: String) {
        if let handler = insertAtCaretHandler, handler(text) {
            return
        }
        let range = selectedRange
        let nsText = editorText as NSString
        let safeLocation = min(range.location, nsText.length)
        let safeLength = min(range.length, nsText.length - safeLocation)
        let safeRange = NSRange(location: safeLocation, length: safeLength)
        let newText = nsText.replacingCharacters(in: safeRange, with: text)
        editorText = newText
        selectedRange = NSRange(location: safeLocation + (text as NSString).length, length: 0)
        selectedText = ""
    }

    /// Splice text at the tracked selection (or append when the range is
    /// stale), leaving the caret after the insertion.
    public func insertTextIntoEditor(_ insertion: String) {
        let nsText = editorText as NSString
        let range: NSRange
        if selectedRange.location != NSNotFound, selectedRange.location + selectedRange.length <= nsText.length {
            range = selectedRange
        } else {
            range = NSRange(location: nsText.length, length: 0)
        }
        let newText = nsText.replacingCharacters(in: range, with: insertion)
        editorText = newText
        let newCaret = range.location + (insertion as NSString).length
        selectedRange = NSRange(location: newCaret, length: 0)
        selectedText = ""
    }

    /// Replace the tracked selection with `replacement` (translation
    /// flow). Returns whether anything was replaced.
    @discardableResult
    public func replaceSelection(with replacement: String) -> Bool {
        guard let (newBody, newRange) = TranslationState.replaceSelectedText(
            in: editorText,
            range: selectedRange,
            with: replacement
        ) else { return false }
        editorText = newBody
        selectedRange = newRange
        selectedText = ""
        return true
    }

    static func parseTags(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
