import Foundation

/// First-run warmth: seed exactly one welcome note into a brand-new vault.
///
/// Called only when the app itself just created the notes folder — the
/// one moment writing into someone's space is ours. The guards below are
/// defense in depth:
/// - Only when the folder holds no note files at all (`.md`, `.textile`,
///   `.cook`). A folder with content is someone's vault — never touched.
/// - Only when `Welcome.md` does not exist.
/// - The file is written through `NoteIO`, so it is an ordinary note:
///   frontmatter, atomic write, Finder-visible.
///
/// Once deleted, the welcome note is never recreated: the caller only
/// invokes this at creation time, and a later first-run sees an existing
/// (now empty) folder, which is left alone.
public enum VaultSeed {
    public static let welcomeFileName = "Welcome.md"

    /// Returns true if the welcome note was written.
    @discardableResult
    public static func seedWelcomeIfNeeded(
        in vaultURL: URL,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: vaultURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else { return false }

        let welcomeURL = vaultURL.appendingPathComponent(welcomeFileName)
        guard !fileManager.fileExists(atPath: welcomeURL.path) else { return false }

        guard let children = try? fileManager.contentsOfDirectory(at: vaultURL, includingPropertiesForKeys: nil) else {
            return false
        }
        let hasNotes = children.contains { NoteLanguage(pathExtension: $0.pathExtension) != nil }
        guard !hasNotes else { return false }

        let note = Note(
            id: NoteIdentity.id(for: welcomeURL, vaultURL: vaultURL),
            fileURL: welcomeURL,
            title: "Welcome to BANAL",
            body: Self.welcomeBody,
            created: now,
            updated: now,
            tags: [],
            published: false,
            modifiedAt: now
        )
        do {
            _ = try NoteIO.write(note, fileManager: fileManager)
            return true
        } catch {
            return false
        }
    }

    private static let welcomeBody = """
    This note is a plain file — Welcome.md — sitting in your notes folder. \
    Finder sees it, any editor can open it, and it syncs however you back up \
    your Documents. BANAL is just the best window onto it.

    Three quiet things:

    - ⌘N makes a new note. ⇧⌘N makes a folder, and folders are real directories on disk.
    - Recipes are notes too. Name a file something.cook, press Edit | Read, and the ingredients line up.
    - Nothing needs an account or the network. Publishing exists under File, and works without any of it.

    Delete this whenever you like. The app won’t mind.
    """
}
