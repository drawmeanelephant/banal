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

    public static func entityID(for note: Note) -> String {
        let trimmed = note.id.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? "untitled" : trimmed
    }

    public static func page(from note: Note) -> BorisPage {
        let entity = entityID(for: note)
        let source = serializeBorisSource(note: note, entityID: entity)
        return BorisPage(
            entityID: entity,
            relativePath: "\(entity).md",
            source: source,
            title: note.displayTitle,
            tags: note.tags,
            updated: note.updated
        )
    }

    public static func serializeBorisSource(note: Note, entityID: String) -> String {
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
                body += "- [\(page.title)](\(page.entityID))\n"
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

        var pages = published.map(page(from:))
        let index = indexPage(siteTitle: configuration.siteTitle, pages: pages)
        pages.insert(index, at: 0)

        for page in pages {
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
