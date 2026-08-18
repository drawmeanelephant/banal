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
        let parsed = try FrontmatterCodec.parse(source)
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        let modified = values.contentModificationDate ?? Date()
        let created = parsed.frontmatter.created ?? values.creationDate ?? modified
        let updated = parsed.frontmatter.updated ?? modified
        let title = parsed.frontmatter.title ?? inferredTitle(from: parsed.body) ?? url.deletingPathExtension().lastPathComponent
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
            extras: parsed.frontmatter.extras,
            contentFingerprint: ContentFingerprint.sha256(of: data)
        )
    }

    public static func encode(_ note: Note) -> String {
        FrontmatterCodec.serialize(
            frontmatter: Frontmatter(
                title: note.title,
                created: note.created,
                updated: note.updated,
                tags: note.tags,
                published: note.published,
                extras: note.extras
            ),
            body: note.body
        )
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
        return saved
    }
}
