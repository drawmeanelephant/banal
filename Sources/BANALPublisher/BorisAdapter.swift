import Foundation
import BANALCore

/// Maps BANAL local notes onto Boris's closed frontmatter grammar.
///
/// Local:  `title`, `created`, `updated`, `tags`, `published`
/// Boris:  `title`, `status`, `tags`  (closed set; extra keys fail `EFRONTMATTER`)
///
/// `created` / `updated` stay local. RSS and the builtin compiler consume them
/// directly. They are never written into a Boris content tree.
public enum BorisAdapter {
    public static func publishedNotes(from notes: [Note]) -> [Note] {
        notes.filter(\.published).sorted { $0.updated > $1.updated }
    }

    /// The Boris entity id for one published note. Delegates to
    /// `entityIDs(for:)` so every caller agrees on the whole assignment.
    public static func entityID(for note: Note, among published: [Note] = []) -> String {
        let group = published.contains(where: { $0.id == note.id }) ? published : published + [note]
        return entityIDs(for: group)[note.id] ?? "untitled"
    }

    /// One entity id per note, unique across the set and valid under the Boris
    /// identity contract (#202). Ids are the sanitized plain names — local
    /// filenames stay untouched, and ids never carry a file extension (so
    /// staged paths and page URLs never double up). Markdown notes claim the
    /// bare stem first; any collision gets Finder-style numbering (`-2`,
    /// `-3`, …). Deterministic regardless of input order.
    public static func entityIDs(for notes: [Note]) -> [String: String] {
        let ordered = notes.sorted { lhs, rhs in
            let left = lhs.language == .markdown ? 0 : 1
            let right = rhs.language == .markdown ? 0 : 1
            return left != right ? left < right : lhs.id < rhs.id
        }
        var assigned: [String: String] = [:]
        var taken = Set<String>()
        for note in ordered {
            var candidate = BorisIdentity.sanitizedEntityID(from: NoteIdentity.droppingLanguageExtension(note.id))
            if candidate.isEmpty {
                candidate = "untitled"
            }
            if taken.contains(candidate) {
                var number = 2
                while taken.contains("\(candidate)-\(number)") {
                    number += 1
                }
                candidate = "\(candidate)-\(number)"
            }
            assigned[note.id] = candidate
            taken.insert(candidate)
        }
        return assigned
    }

    /// Where a page's source lands inside the staging tree. Derived from the
    /// entity id (Boris-shaped, no whitespace) rather than the local filename.
    public static func sourceRelativePath(for note: Note, entityID: String) -> String {
        "\(entityID).\(note.language.pathExtension)"
    }

    public static func page(from note: Note, among published: [Note] = []) -> BorisPage {
        let entity = entityID(for: note, among: published)
        let source = serializeBorisSource(note: note, entityID: entity)
        return BorisPage(
            entityID: entity,
            relativePath: sourceRelativePath(for: note, entityID: entity),
            source: source,
            title: note.displayTitle,
            tags: note.tags,
            updated: note.updated,
            language: note.language
        )
    }

    public static func serializeBorisSource(note: Note, entityID: String) -> String {
        if note.language == .cooklang {
            var fm = Frontmatter()
            fm.title = note.displayTitle
            fm.tags = note.tags
            fm.published = true
            return CookMetadata.serialize(frontmatter: fm, body: note.body)
        }
        var lines = ["---"]
        lines.append("id: \(entityID)")
        lines.append("title: \(escape(note.displayTitle))")
        lines.append("status: published")
        if !note.tags.isEmpty {
            let items = note.tags.map(escapeTag).joined(separator: ", ")
            lines.append("tags: [\(items)]")
        }
        lines.append("---")
        var body = note.body
        if !body.hasPrefix("\n") {
            body = "\n" + body
        }
        if !body.hasSuffix("\n") {
            body.append("\n")
        }
        return lines.joined(separator: "\n") + "\n" + body
    }

    public static func indexPage(siteTitle: String, pages: [BorisPage]) -> BorisPage {
        var body = "\n# \(siteTitle)\n\n"
        if pages.isEmpty {
            body += "No published notes.\n"
        } else {
            for page in pages {
                body += "- [\(page.title)](\(page.entityID).html)\n"
            }
        }
        let source = """
        ---
        id: index
        title: \(escape(siteTitle))
        status: published
        tags: [index]
        ---
        \(body)
        """
        return BorisPage(
            entityID: "index",
            relativePath: "index.md",
            source: source,
            title: siteTitle,
            tags: ["index"],
            updated: pages.first?.updated ?? Date()
        )
    }

    public static func stage(
        notes: [Note],
        configuration: PublishConfiguration,
        assetsSource: URL?,
        fileManager: FileManager = .default
    ) throws -> (contentRoot: URL, pages: [BorisPage]) {
        let published = publishedNotes(from: notes)
        if published.isEmpty {
            throw PublishError.noPublishedNotes
        }
        let staging = configuration.stagingDirectory
        if fileManager.fileExists(atPath: staging.path) {
            try fileManager.removeItem(at: staging)
        }
        let content = staging.appendingPathComponent("content", isDirectory: true)
        let layouts = staging.appendingPathComponent("layouts", isDirectory: true)
        try fileManager.createDirectory(at: content, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layouts, withIntermediateDirectories: true)
        try BundledTheme.mainLayout.data(using: .utf8)?.write(
            to: layouts.appendingPathComponent("main.html"),
            options: .atomic
        )

        var pages = published.map { page(from: $0, among: published) }
        let index = indexPage(siteTitle: configuration.siteTitle, pages: pages)
        pages.insert(index, at: 0)

        // Boris (and the builtin compiler) only eat Markdown. Textile and
        // Cooklang stay on the page list for Oliver; they must not land in
        // `content/` or a markdown-only Boris tree will reject the folder.
        for page in pages where page.language == .markdown {
            let destination = content.appendingPathComponent(page.relativePath)
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(page.source.utf8).write(to: destination, options: .atomic)
        }

        if let assetsSource, fileManager.fileExists(atPath: assetsSource.path) {
            let dest = staging.appendingPathComponent("assets", isDirectory: true)
            try? fileManager.removeItem(at: dest)
            try fileManager.copyItem(at: assetsSource, to: dest)
        }

        return (content, pages)
    }

    private static func escape(_ value: String) -> String {
        if value.contains(":") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: ""))\""
        }
        return value
    }

    private static func escapeTag(_ value: String) -> String {
        if value.contains(",") || value.contains(" ") {
            return "\"\(value.replacingOccurrences(of: "\"", with: ""))\""
        }
        return value
    }
}

public enum BundledTheme {
    /// Boris-compatible layout using the documented slot markers.
    public static let mainLayout = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>{{title}} · BANAL</title>
      <style>
        :root { color-scheme: light dark; font-family: ui-sans-serif, system-ui, sans-serif; }
        body { max-width: 42rem; margin: 0 auto; padding: 2rem 1.25rem 4rem; line-height: 1.55; }
        a { color: inherit; }
        nav { font-family: ui-sans-serif, system-ui, sans-serif; font-size: 0.9rem; margin-bottom: 1.5rem; }
        nav ul { list-style: none; margin: 0; padding: 0; }
        nav li { margin: 0.25rem 0; }
        header p { opacity: 0.7; font-size: 0.85rem; }
        article :first-child { margin-top: 0; }
        pre, code { font-family: ui-monospace, Menlo, monospace; font-size: 0.92em; }
        pre { padding: 0.85rem 1rem; overflow: auto; background: color-mix(in srgb, CanvasText 6%, Canvas); }
        img { max-width: 100%; height: auto; }
      </style>
    </head>
    <body>
    {{nav}}
    <main>
    {{content}}
    </main>
    </body>
    </html>
    """
}
