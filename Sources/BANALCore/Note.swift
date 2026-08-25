import CryptoKit
import Foundation

/// The language of a note is its file extension. Disk is truth.
public enum NoteLanguage: String, Equatable, Hashable, Sendable, CaseIterable {
    case markdown
    case textile
    case cooklang

    public var pathExtension: String {
        switch self {
        case .markdown: return "md"
        case .textile: return "textile"
        case .cooklang: return "cook"
        }
    }

    /// Markdown and Textile store BANAL keys in the local YAML fence.
    /// Cooklang does not — that would fake YAML onto a recipe.
    public var usesFrontmatter: Bool {
        self != .cooklang
    }

    public init?(pathExtension: String) {
        switch pathExtension.lowercased() {
        case "md": self = .markdown
        case "textile": self = .textile
        case "cook": self = .cooklang
        default: return nil
        }
    }
}

/// Tiny new-recipe source: one ingredient, one step. Title is written
/// as Cooklang `>>` metadata on save, not as a YAML fence.
public enum CooklangStub {
    public static let body = """
    Add @ingredient{} to the pan.

    Stir.
    """
}

/// One local note. The file on disk is the source of truth.
public struct Note: Identifiable, Equatable, Sendable {
    /// Vault-relative POSIX path including the language extension. Example: `inbox/hello.md`.
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
    /// Unknown frontmatter keys preserved for round-trip (Markdown/Textile only).
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

    public var language: NoteLanguage {
        NoteLanguage(pathExtension: fileURL.pathExtension) ?? .markdown
    }

    public var folder: String? {
        let parent = (id as NSString).deletingLastPathComponent
        return parent.isEmpty ? nil : parent
    }

    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if language == .cooklang {
            return fileURL.deletingPathExtension().lastPathComponent
        }
        return inferredTitle(from: body) ?? fileURL.deletingPathExtension().lastPathComponent
    }

    public var snippet: String {
        let collapsed = body
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix(">>") }
            .joined(separator: " ")
        if collapsed.count <= 140 { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: 140)
        return String(collapsed[..<end]) + "…"
    }

    public func matches(query: String, ingredients: [String] = []) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty { return true }
        var haystacks = [displayTitle, body, tags.joined(separator: " "), NoteIdentity.droppingLanguageExtension(id)]
        if language == .cooklang {
            if !ingredients.isEmpty {
                haystacks.append(contentsOf: ingredients)
            } else {
                haystacks.append(contentsOf: CooklangScanner.ingredientNames(in: body))
            }
        }
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
        return relative.replacingOccurrences(of: "\\", with: "/")
    }

    /// `Recipes/risotto.cook` → `Recipes/risotto`. Search uses this so
    /// querying "cook" does not match every recipe.
    public static func droppingLanguageExtension(_ relative: String) -> String {
        let ext = (relative as NSString).pathExtension
        guard NoteLanguage(pathExtension: ext) != nil else { return relative }
        return (relative as NSString).deletingPathExtension
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

    /// Plain names: a note is called what it is called. The file keeps
    /// the title's case and accents; only what cannot be a single path
    /// component gets rewritten. Finder-style numbering ("Risotto 2.md")
    /// happens at collision time in the store, not here.
    public static func filenameLeaf(from title: String, ext: String) -> String {
        var name = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .components(separatedBy: CharacterSet.newlines)
            .joined(separator: " ")
        while name.hasPrefix(".") {
            name.removeFirst()
        }
        while name.contains("  ") {
            name = name.replacingOccurrences(of: "  ", with: " ")
        }
        if name.count > 80 {
            name = String(name.prefix(80))
        }
        while name.hasSuffix("-") {
            name.removeLast()
        }
        name = name.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            name = "Untitled"
        }
        return "\(name).\(ext)"
    }

    /// The comparable form of a filename stem or title: case-, accent-,
    /// and width-insensitive, with separators already folded. Used to
    /// decide whether a file's name follows its title.
    public static func canonicalName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
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
        if line == "---" || line == "+++" { continue }
        if line.hasPrefix(">>") { continue }
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
