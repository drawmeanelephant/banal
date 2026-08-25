import Foundation
import BANALCore
import BANALPublisher

/// Scripted read/write over the same `NoteStore` the app uses.
///
/// Every operation opens a fresh store against the resolved vault — the same
/// route the App Intents take — so scripts behave exactly like edits made in
/// Finder: the running app observes them through its filesystem monitors.
/// Disk is truth; there is no second database behind the dictionary.
@MainActor
public enum NoteScripting {
    public struct ScriptingFailure: LocalizedError {
        public let message: String
        public var errorDescription: String? { message }
        public init(_ message: String) { self.message = message }
    }

    static func withStore<T>(_ body: (NoteStore) throws -> T) throws -> T {
        let store = try IntentVaultResolver.loadStore()
        defer { store.flush() }
        return try body(store)
    }

    // MARK: - Read

    public static func listNotes() throws -> [[String: Any]] {
        try withStore { store in
            store.notes
                .sorted { $0.updated > $1.updated }
                .map(noteRecord)
        }
    }

    public static func readNote(id: String) throws -> [String: Any] {
        try withStore { store in
            guard let note = store.note(id: id) else {
                throw ScriptingFailure("No note \"\(id)\" in the notes folder.")
            }
            var record = noteRecord(note)
            record["body"] = note.body
            return record
        }
    }

    // MARK: - Write

    @discardableResult
    public static func createNote(
        title: String?,
        body: String?,
        folder: String?,
        language rawLanguage: String?,
        published: Bool
    ) throws -> [String: Any] {
        let languageName = (rawLanguage ?? "markdown").lowercased()
        guard let language = NoteLanguage(rawValue: languageName) else {
            throw ScriptingFailure("language must be markdown, textile, or cooklang.")
        }
        return try withStore { store in
            var note = try store.createNote(
                title: title ?? "Untitled",
                body: body,
                folder: folder,
                language: language
            )
            if published != note.published {
                note.published = true
                store.update(note, debounce: false)
            }
            store.flush()
            return noteRecord(note)
        }
    }

    @discardableResult
    public static func updateNoteBody(id: String, body: String) throws -> [String: Any] {
        try withStore { store in
            guard var note = store.note(id: id) else {
                throw ScriptingFailure("No note \"\(id)\" in the notes folder.")
            }
            note.body = body
            store.update(note, debounce: false)
            store.flush()
            return noteRecord(note)
        }
    }

    @discardableResult
    public static func setPublished(_ published: Bool, id: String) throws -> [String: Any] {
        try withStore { store in
            guard store.note(id: id) != nil else {
                throw ScriptingFailure("No note \"\(id)\" in the notes folder.")
            }
            store.setPublished(published, id: id)
            store.flush()
            guard let updated = store.note(id: id) else {
                throw ScriptingFailure("Note \"\(id)\" vanished while updating.")
            }
            return noteRecord(updated)
        }
    }

    /// The same pipeline as File → Publish Site. Returns the status sentence.
    @discardableResult
    public static func publishSite() throws -> String {
        let vaultURL = try IntentVaultResolver.resolveVaultURL()
        let vaultConfiguration = VaultBootstrap.load(from: vaultURL)
        let configuration = PublishConfiguration.default(for: vaultConfiguration)
        let publisher = BANALPublisher.make(configuration: configuration)
        let store = try IntentVaultResolver.loadStore()
        defer { store.flush() }
        return try publisher.publish(
            notes: store.notes,
            vault: vaultConfiguration,
            configuration: configuration
        ).statusCopy
    }

    // MARK: - Records

    /// JSONSerialization refuses `Date`, and replies travel as JSON text —
    /// timestamps go out as ISO-8601 strings.
    private static let iso8601 = ISO8601DateFormatter()

    static func noteRecord(_ note: Note) -> [String: Any] {
        [
            "id": note.id,
            "title": note.displayTitle,
            "folder": note.folder ?? "",
            "published": note.published,
            "tags": note.tags,
            "updated": iso8601.string(from: note.updated),
        ]
    }
}
