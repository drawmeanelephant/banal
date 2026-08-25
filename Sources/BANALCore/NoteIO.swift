import Foundation

public enum NoteIOError: Error, Equatable, Sendable {
    case notUTF8(URL)
    case missingFile(URL)
    case writeFailed(URL)
}

public enum NoteIO {
    public static func load(url: URL, vaultURL: URL, fileManager: FileManager = .default) throws -> Note {
        guard fileManager.fileExists(atPath: url.path) else {
            throw NoteIOError.missingFile(url)
        }
        let data = try Data(contentsOf: url)
        guard let source = String(data: data, encoding: .utf8) else {
            throw NoteIOError.notUTF8(url)
        }
        let language = NoteLanguage(pathExtension: url.pathExtension) ?? .markdown
        let parsed: ParsedNoteDocument
        if language.usesFrontmatter {
            parsed = try FrontmatterCodec.parse(source)
        } else {
            parsed = CookMetadata.parse(source)
        }
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey, .fileSizeKey])
        let modified = values.contentModificationDate ?? Date()
        let created = parsed.frontmatter.created ?? values.creationDate ?? modified
        let updated = parsed.frontmatter.updated ?? modified
        let title: String
        if language == .cooklang {
            title = parsed.frontmatter.title ?? url.deletingPathExtension().lastPathComponent
        } else {
            title = parsed.frontmatter.title ?? inferredTitle(from: parsed.body) ?? url.deletingPathExtension().lastPathComponent
        }
        return Note(
            id: NoteIdentity.id(for: url, vaultURL: vaultURL),
            fileURL: url,
            title: title,
            body: parsed.body,
            created: created,
            updated: updated,
            tags: parsed.frontmatter.tags,
            published: parsed.frontmatter.published,
            modifiedAt: modified,
            fileSize: values.fileSize,
            extras: parsed.frontmatter.extras,
            contentFingerprint: ContentFingerprint.sha256(of: data)
        )
    }

    public static func encode(_ note: Note) -> String {
        let frontmatter = Frontmatter(
            title: note.title,
            created: note.created,
            updated: note.updated,
            tags: note.tags,
            published: note.published,
            extras: note.extras
        )
        if note.language.usesFrontmatter {
            return FrontmatterCodec.serialize(frontmatter: frontmatter, body: note.body)
        }
        return CookMetadata.serialize(frontmatter: frontmatter, body: note.body)
    }

    /// Atomic replace so readers never see a torn file.
    @discardableResult
    public static func write(_ note: Note, fileManager: FileManager = .default) throws -> Note {
        let encoded = encode(note)
        let data = Data(encoded.utf8)
        try fileManager.createDirectory(at: note.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var coordinatorError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: note.fileURL, options: .forReplacing, error: &coordinatorError) { url in
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let writeError { throw writeError }
        let values = try note.fileURL.resourceValues(forKeys: [.contentModificationDateKey])
        var saved = note
        saved.contentFingerprint = ContentFingerprint.sha256(of: data)
        saved.modifiedAt = values.contentModificationDate ?? Date()
        saved.fileSize = data.count
        return saved
    }
}

/// Cheap on-disk identity of a note file: mtime + size (#186).
/// `NoteStore.reloadAll` stats each URL before reading and reuses the
/// in-memory note when the signature matches, so unchanged files are
/// never re-read and their list rows keep their identity.
public struct NoteFileStat: Equatable, Sendable {
    public let modifiedAt: Date
    public let fileSize: Int

    public init(modifiedAt: Date, fileSize: Int) {
        self.modifiedAt = modifiedAt
        self.fileSize = fileSize
    }

    /// `nil` when the file cannot be stat'd (it vanished mid-scan); the
    /// caller falls back to reading.
    public init?(url: URL, fileManager: FileManager = .default) {
        guard
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
            let modifiedAt = values.contentModificationDate,
            let fileSize = values.fileSize
        else { return nil }
        self.init(modifiedAt: modifiedAt, fileSize: fileSize)
    }

    /// True when `note` was loaded from a file with exactly this stat —
    /// the bytes cannot have changed without moving the mtime or the
    /// size. A note with no recorded size (never loaded or written) is
    /// never a match.
    public func matches(_ note: Note) -> Bool {
        guard let size = note.fileSize else { return false }
        return size == fileSize && modifiedAt == note.modifiedAt
    }
}
