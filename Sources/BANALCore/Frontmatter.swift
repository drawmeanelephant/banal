import Foundation

/// Lightweight local-note frontmatter. This is **not** Boris's closed product
/// grammar and **not** a YAML 1.2 parser.
///
/// Local keys (BANAL storage contract):
/// `title`, `created`, `updated`, `tags`, `published`.
///
/// Extra keys are preserved on round-trip so Finder/Vim edits are not stripped.
/// Publishing maps this document onto Boris's closed set via `BANALPublisher`.
public struct Frontmatter: Equatable, Sendable {
    public var title: String?
    public var created: Date?
    public var updated: Date?
    public var tags: [String]
    public var published: Bool
    /// Unknown keys in source order. Values are the raw trimmed text after `:`.
    public var extras: [FrontmatterExtra]

    public init(
        title: String? = nil,
        created: Date? = nil,
        updated: Date? = nil,
        tags: [String] = [],
        published: Bool = false,
        extras: [FrontmatterExtra] = []
    ) {
        self.title = title
        self.created = created
        self.updated = updated
        self.tags = tags
        self.published = published
        self.extras = extras
    }

    public static let empty = Frontmatter()
}

public struct FrontmatterExtra: Equatable, Sendable {
    public var key: String
    public var rawValue: String

    public init(key: String, rawValue: String) {
        self.key = key
        self.rawValue = rawValue
    }
}

public struct ParsedNoteDocument: Equatable, Sendable {
    public var hasFrontmatter: Bool
    public var frontmatter: Frontmatter
    public var body: String
    /// Byte offset of `body` in the original UTF-8 source.
    public var bodyOffset: Int

    public init(hasFrontmatter: Bool, frontmatter: Frontmatter, body: String, bodyOffset: Int) {
        self.hasFrontmatter = hasFrontmatter
        self.frontmatter = frontmatter
        self.body = body
        self.bodyOffset = bodyOffset
    }
}

public enum FrontmatterError: Error, Equatable, Sendable {
    case invalidUTF8
    case leadingBOM
    case unclosedFence
    case malformedField(line: Int)
    case duplicateKey(String, line: Int)
    case emptyValue(key: String, line: Int)
    case unsupportedForm(line: Int, reason: String)
    case titleTooLong
    case tooManyTags
    case tagTooLong
    case sourceTooLarge
}

public enum FrontmatterCodec {
    public static let maxTitleBytes = 512
    public static let maxTagBytes = 64
    public static let maxTagCount = 32
    public static let maxSourceBytes = 1_048_576
    public static let knownKeys: Set<String> = ["title", "created", "updated", "tags", "published"]

    public static func parse(_ source: String) throws -> ParsedNoteDocument {
        let utf8Count = source.utf8.count
        if utf8Count > maxSourceBytes {
            throw FrontmatterError.sourceTooLarge
        }
        if source.utf8.starts(with: [0xEF, 0xBB, 0xBF]) {
            throw FrontmatterError.leadingBOM
        }

        guard source.hasPrefix("---") else {
            return ParsedNoteDocument(hasFrontmatter: false, frontmatter: .empty, body: source, bodyOffset: 0)
        }

        let afterOpen = source.dropFirst(3)
        guard afterOpen.first == "\n" || afterOpen.hasPrefix("\r\n") else {
            // "---" not a complete first line — treat as body, matching Boris fence rules.
            return ParsedNoteDocument(hasFrontmatter: false, frontmatter: .empty, body: source, bodyOffset: 0)
        }

        let rest: Substring
        if afterOpen.hasPrefix("\r\n") {
            rest = afterOpen.dropFirst(2)
        } else {
            rest = afterOpen.dropFirst()
        }

        var lineNumber = 2
        var cursor = rest.startIndex
        var fields: [(key: String, value: String, line: Int)] = []
        var sawKeys = Set<String>()

        while cursor < rest.endIndex {
            let lineEnd = rest[cursor...].firstIndex(where: { $0 == "\n" }) ?? rest.endIndex
            var line = rest[cursor..<lineEnd]
            if line.hasSuffix("\r") {
                line = line.dropLast()
            }
            let next = lineEnd == rest.endIndex ? rest.endIndex : rest.index(after: lineEnd)

            if line == "---" {
                let bodyStart = next
                let body = String(rest[bodyStart...])
                let bodyOffset = source.distance(from: source.startIndex, to: bodyStart)
                let fm = try assemble(fields)
                return ParsedNoteDocument(
                    hasFrontmatter: true,
                    frontmatter: fm,
                    body: body,
                    bodyOffset: bodyOffset
                )
            }

            if !line.isEmpty && !line.allSatisfy({ $0 == " " || $0 == "\t" }) {
                if line.first == " " || line.first == "\t" {
                    throw FrontmatterError.unsupportedForm(line: lineNumber, reason: "indented keys are not supported")
                }
                if line.hasPrefix("- ") {
                    throw FrontmatterError.unsupportedForm(line: lineNumber, reason: "YAML sequences are not supported")
                }
                guard let colon = line.firstIndex(of: ":") else {
                    throw FrontmatterError.malformedField(line: lineNumber)
                }
                let key = String(line[..<colon])
                if key.isEmpty {
                    throw FrontmatterError.malformedField(line: lineNumber)
                }
                if sawKeys.contains(key) {
                    throw FrontmatterError.duplicateKey(key, line: lineNumber)
                }
                sawKeys.insert(key)
                let raw = String(line[line.index(after: colon)...])
                fields.append((key, raw, lineNumber))
            }

            cursor = next
            lineNumber += 1
        }

        throw FrontmatterError.unclosedFence
    }

    public static func serialize(frontmatter: Frontmatter, body: String) -> String {
        var lines: [String] = ["---"]
        if let title = frontmatter.title, !title.isEmpty {
            lines.append("title: \(escapeScalar(title))")
        }
        if let created = frontmatter.created {
            lines.append("created: \(DateFormatting.string(from: created))")
        }
        if let updated = frontmatter.updated {
            lines.append("updated: \(DateFormatting.string(from: updated))")
        }
        if !frontmatter.tags.isEmpty {
            let items = frontmatter.tags.map(escapeTagItem).joined(separator: ", ")
            lines.append("tags: [\(items)]")
        }
        lines.append("published: \(frontmatter.published ? "true" : "false")")
        for extra in frontmatter.extras where !Self.knownKeys.contains(extra.key) {
            lines.append("\(extra.key): \(extra.rawValue)")
        }
        lines.append("---")
        var output = lines.joined(separator: "\n")
        output.append("\n")
        if !body.isEmpty {
            if !body.hasPrefix("\n") {
                // Keep a blank line after the fence when the body does not already start with one.
            }
            output.append(body)
            if !body.hasSuffix("\n") {
                output.append("\n")
            }
        }
        return output
    }

    // MARK: - Internals

    private static func assemble(_ fields: [(key: String, value: String, line: Int)]) throws -> Frontmatter {
        var fm = Frontmatter()
        for field in fields {
            switch field.key {
            case "title":
                let value = try parseScalar(field.value, key: field.key, line: field.line)
                if value.utf8.count > maxTitleBytes {
                    throw FrontmatterError.titleTooLong
                }
                fm.title = value
            case "created":
                let value = try parseScalar(field.value, key: field.key, line: field.line)
                fm.created = DateFormatting.date(from: value)
            case "updated":
                let value = try parseScalar(field.value, key: field.key, line: field.line)
                fm.updated = DateFormatting.date(from: value)
            case "published":
                let value = try parseScalar(field.value, key: field.key, line: field.line)
                fm.published = parseBool(value)
            case "tags":
                fm.tags = try parseTags(field.value, line: field.line)
            default:
                fm.extras.append(FrontmatterExtra(key: field.key, rawValue: trimASCII(field.value)))
            }
        }
        return fm
    }

    private static func parseScalar(_ raw: String, key: String, line: Int) throws -> String {
        let trimmed = trimASCII(raw)
        if trimmed.isEmpty {
            throw FrontmatterError.emptyValue(key: key, line: line)
        }
        if trimmed.hasPrefix("'") {
            throw FrontmatterError.unsupportedForm(line: line, reason: "single-quoted values are not supported")
        }
        if trimmed == "|" || trimmed == ">" {
            throw FrontmatterError.unsupportedForm(line: line, reason: "YAML block scalars are not supported")
        }
        if trimmed.hasPrefix("{") {
            throw FrontmatterError.unsupportedForm(line: line, reason: "YAML flow mappings are not supported")
        }
        if trimmed.hasPrefix("\"") {
            guard trimmed.count >= 2, trimmed.last == "\"" else {
                throw FrontmatterError.unsupportedForm(line: line, reason: "malformed double-quoted string")
            }
            let inner = String(trimmed.dropFirst().dropLast())
            if inner.isEmpty || inner.contains("\"") {
                throw FrontmatterError.unsupportedForm(line: line, reason: "malformed double-quoted string")
            }
            return inner
        }
        if trimmed.hasPrefix("[") && key != "tags" {
            throw FrontmatterError.unsupportedForm(line: line, reason: "lists are only supported on tags")
        }
        return trimmed
    }

    private static func parseTags(_ raw: String, line: Int) throws -> [String] {
        let trimmed = trimASCII(raw)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else {
            throw FrontmatterError.unsupportedForm(line: line, reason: "tags must be a list like [a, b]")
        }
        let inner = trimmed.dropFirst().dropLast()
        if inner.allSatisfy({ $0 == " " || $0 == "\t" }) || inner.isEmpty {
            return []
        }
        var tags: [String] = []
        var current = ""
        var inQuote = false
        for ch in inner {
            if ch == "\"" {
                inQuote.toggle()
                current.append(ch)
                continue
            }
            if ch == "," && !inQuote {
                let item = try parseTagItem(current, line: line)
                tags.append(item)
                current = ""
                continue
            }
            current.append(ch)
        }
        if inQuote {
            throw FrontmatterError.unsupportedForm(line: line, reason: "unterminated quoted tag")
        }
        let last = try parseTagItem(current, line: line)
        tags.append(last)
        if tags.count > maxTagCount {
            throw FrontmatterError.tooManyTags
        }
        return tags
    }

    private static func parseTagItem(_ raw: String, line: Int) throws -> String {
        let trimmed = trimASCII(raw)
        if trimmed.isEmpty {
            throw FrontmatterError.unsupportedForm(line: line, reason: "empty tag")
        }
        let value: String
        if trimmed.hasPrefix("\"") {
            guard trimmed.count >= 2, trimmed.last == "\"" else {
                throw FrontmatterError.unsupportedForm(line: line, reason: "malformed quoted tag")
            }
            value = String(trimmed.dropFirst().dropLast())
        } else {
            value = trimmed
        }
        if value.utf8.count > maxTagBytes {
            throw FrontmatterError.tagTooLong
        }
        if value.isEmpty {
            throw FrontmatterError.unsupportedForm(line: line, reason: "empty tag")
        }
        return value
    }

    private static func parseBool(_ value: String) -> Bool {
        switch value.lowercased() {
        case "true", "yes", "1":
            return true
        default:
            return false
        }
    }

    private static func trimASCII(_ value: String) -> String {
        String(value.drop(while: { $0 == " " || $0 == "\t" }).reversed().drop(while: { $0 == " " || $0 == "\t" }).reversed())
    }

    private static func escapeScalar(_ value: String) -> String {
        if value.contains(":") || value.hasPrefix(" ") || value.hasSuffix(" ") || value.contains("\"") {
            let sanitized = value.replacingOccurrences(of: "\"", with: "")
            return "\"\(sanitized)\""
        }
        return value
    }

    private static func escapeTagItem(_ value: String) -> String {
        if value.contains(",") || value.contains(" ") || value.contains(":") {
            return "\"\(value.replacingOccurrences(of: "\"", with: ""))\""
        }
        return value
    }
}

public enum DateFormatting {
    public static func string(from date: Date) -> String {
        makeISO().string(from: date)
    }

    public static func date(from string: String) -> Date? {
        if let parsed = makeISO().date(from: string) {
            return parsed
        }
        let day = ISO8601DateFormatter()
        day.formatOptions = [.withFullDate]
        return day.date(from: string)
    }

    private static func makeISO() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
