import CryptoKit
import Foundation

/// One local Markdown note. The file on disk is the source of truth.
public struct Note: Identifiable, Equatable, Sendable {
    /// Vault-relative POSIX path without the `.md` extension. Example: `inbox/hello`.
    public var id: String
    public var fileURL: URL
    public var title: String
    public var body: String
    public var created: Date
    public var updated: Date
    public var tags: [String]
    public var published: Bool
    /// Filesystem modification timestamp (`mtime`).
    public var modifiedAt: Date
    /// Unknown frontmatter keys preserved for round-trip.
    public var extras: [FrontmatterExtra]
    /// SHA-256 of the last bytes we wrote or successfully loaded.
    public var contentFingerprint: String

    public init(
        id: String,
        fileURL: URL,
        title: String,
        body: String,
        created: Date,
        updated: Date,
        tags: [String] = [],
        published: Bool = false,
        modifiedAt: Date,
        extras: [FrontmatterExtra] = [],
        contentFingerprint: String = ""
    ) {
        self.id = id
        self.fileURL = fileURL
        self.title = title
        self.body = body
        self.created = created
        self.updated = updated
        self.tags = tags
        self.published = published
        self.modifiedAt = modifiedAt
        self.extras = extras
        self.contentFingerprint = contentFingerprint
    }

    public var folder: String? {
        let parent = (id as NSString).deletingLastPathComponent
        return parent.isEmpty ? nil : parent
    }

    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return inferredTitle(from: body) ?? (id as NSString).lastPathComponent
    }

    public var snippet: String {
        let collapsed = body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if collapsed.count <= 140 { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: 140)
        return String(collapsed[..<end]) + "…"
    }

    public func matches(query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty { return true }
        let haystacks = [displayTitle, body, tags.joined(separator: " "), id]
        return haystacks.contains { $0.localizedCaseInsensitiveContains(needle) }
    }
}

public enum NoteIdentity {
    public static func id(for fileURL: URL, vaultURL: URL) -> String {
        let root = vaultURL.standardizedFileURL.path
        let full = fileURL.standardizedFileURL.path
        var relative = full
        if full.hasPrefix(root) {
            relative = String(full.dropFirst(root.count))
        }
        if relative.hasPrefix("/") {
            relative.removeFirst()
        }
        if relative.lowercased().hasSuffix(".md") {
            relative = String(relative.dropLast(3))
        }
        return relative.replacingOccurrences(of: "\\", with: "/")
    }

    public static func slug(from title: String, now: Date = Date()) -> String {
        let day = DayStamp.string(from: now)
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "untitled" : trimmed
        let scalars = base.lowercased().unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return "-"
        }
        var slug = String(scalars)
        while slug.contains("--") {
            slug = slug.replacingOccurrences(of: "--", with: "-")
        }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if slug.isEmpty { slug = "untitled" }
        if slug.count > 48 {
            slug = String(slug.prefix(48)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
        return "\(day)-\(slug)"
    }
}

public enum DayStamp {
    public static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

public func inferredTitle(from body: String) -> String? {
    for raw in body.split(whereSeparator: \.isNewline) {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty { continue }
        if line.hasPrefix("#") {
            let stripped = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
            return stripped.isEmpty ? nil : String(stripped)
        }
        return String(line)
    }
    return nil
}

public enum ContentFingerprint {
    public static func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
