import Foundation

/// Cooklang metadata for BANAL local keys. This is **not** YAML.
///
/// `.cook` files keep Cooklang's `>> key: value` lines. BANAL stores
/// `title`, `tags`, and `published` there. Unknown `>>` lines (servings,
/// source, time) stay in the body so Oliver still sees them. Created and
/// updated come from the filesystem.
public enum CookMetadata {
    public static let knownKeys: Set<String> = ["title", "tags", "published"]

    public static func parse(_ source: String) -> ParsedNoteDocument {
        var fm = Frontmatter()
        var kept: [String] = []
        var inLeadingMeta = true
        var extracted = false
        var sawBody = false

        var cursor = source.startIndex
        while cursor < source.endIndex {
            let lineEnd = source[cursor...].firstIndex(of: "\n") ?? source.endIndex
            var line = source[cursor..<lineEnd]
            if line.hasSuffix("\r") {
                line = line.dropLast()
            }
            let next = lineEnd == source.endIndex ? source.endIndex : source.index(after: lineEnd)
            let text = String(line)

            if inLeadingMeta {
                if text.isEmpty || text.allSatisfy({ $0 == " " || $0 == "\t" }) {
                    inLeadingMeta = false
                    if !kept.isEmpty {
                        kept.append(text)
                        sawBody = true
                    }
                    cursor = next
                    continue
                }
                if let field = parseLine(text) {
                    if knownKeys.contains(field.key) {
                        apply(field, to: &fm)
                        extracted = true
                    } else {
                        kept.append(text)
                        sawBody = true
                    }
                    cursor = next
                    continue
                }
                inLeadingMeta = false
            }

            kept.append(text)
            sawBody = true
            cursor = next
        }

        var body = kept.joined(separator: "\n")
        if sawBody, source.hasSuffix("\n"), !body.hasSuffix("\n") {
            body.append("\n")
        }
        return ParsedNoteDocument(
            hasFrontmatter: extracted,
            frontmatter: fm,
            body: body,
            bodyOffset: max(0, source.utf8.count - body.utf8.count)
        )
    }

    public static func serialize(frontmatter: Frontmatter, body: String) -> String {
        var lines: [String] = []
        if let title = frontmatter.title, !title.isEmpty {
            lines.append(">> title: \(title)")
        }
        if !frontmatter.tags.isEmpty {
            lines.append(">> tags: \(frontmatter.tags.joined(separator: ", "))")
        }
        if frontmatter.published {
            lines.append(">> published: true")
        }
        for extra in frontmatter.extras where !knownKeys.contains(extra.key) {
            lines.append(">> \(extra.key): \(extra.rawValue)")
        }

        var output = ""
        if !lines.isEmpty {
            output.append(lines.joined(separator: "\n"))
            output.append("\n")
            if !body.isEmpty {
                output.append("\n")
            }
        }
        output.append(body)
        if !body.isEmpty, !body.hasSuffix("\n") {
            output.append("\n")
        }
        return output
    }

    // MARK: - Internals

    private static func parseLine(_ line: String) -> (key: String, value: String)? {
        var rest = Substring(line)
        guard rest.hasPrefix(">>") else { return nil }
        rest = rest.dropFirst(2)
        while rest.first == " " || rest.first == "\t" {
            rest = rest.dropFirst()
        }
        guard let colon = rest.firstIndex(of: ":") else { return nil }
        let key = rest[..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        let value = rest[rest.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (key, value)
    }

    private static func apply(_ field: (key: String, value: String), to fm: inout Frontmatter) {
        switch field.key {
        case "title":
            if !field.value.isEmpty { fm.title = field.value }
        case "published":
            fm.published = parseBool(field.value)
        case "tags":
            fm.tags = parseTags(field.value)
        default:
            break
        }
    }

    private static func parseTags(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func parseBool(_ value: String) -> Bool {
        switch value.lowercased() {
        case "true", "yes", "1":
            return true
        default:
            return false
        }
    }
}
