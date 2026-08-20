import Foundation

/// Filesystem layout of a BANAL vault. Disk is the source of truth.
///
/// ```
/// <vault>/
///   Welcome.md
///   a-page.textile
///   Recipes/risotto.cook
///   assets/          # flat local media
///   .banal/          # app metadata (not notes)
///     config.json
///   .publish/        # last generated site artifact (optional)
/// ```
public struct VaultConfiguration: Equatable, Sendable {
    public var rootURL: URL
    public var siteTitle: String
    public var siteBaseURL: String
    public var siteAuthor: String
    public var borisBinaryPath: String?
    public var oliverBinaryPath: String?
    public var cloudflareAccountID: String?
    public var cloudflareProjectName: String
    public var cloudflareCustomDomain: String

    public init(
        rootURL: URL,
        siteTitle: String = "Notes",
        siteBaseURL: String = "",
        siteAuthor: String = "",
        borisBinaryPath: String? = nil,
        oliverBinaryPath: String? = nil,
        cloudflareAccountID: String? = nil,
        cloudflareProjectName: String = "banal-notes",
        cloudflareCustomDomain: String = ""
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.siteTitle = siteTitle
        self.siteBaseURL = siteBaseURL
        self.siteAuthor = siteAuthor
        self.borisBinaryPath = borisBinaryPath
        self.oliverBinaryPath = oliverBinaryPath
        self.cloudflareAccountID = cloudflareAccountID
        self.cloudflareProjectName = cloudflareProjectName
        self.cloudflareCustomDomain = cloudflareCustomDomain
    }

    public var assetsURL: URL { rootURL.appendingPathComponent("assets", isDirectory: true) }
    public var metadataURL: URL { rootURL.appendingPathComponent(".banal", isDirectory: true) }
    public var configURL: URL { metadataURL.appendingPathComponent("config.json") }
    public var publishURL: URL { rootURL.appendingPathComponent(".publish", isDirectory: true) }

    public static let reservedDirectoryNames: Set<String> = [
        "assets",
        ".banal",
        ".publish",
        ".git",
        "dist",
        ".boris",
        ".boris-cache",
    ]

    public func isReservedDirectory(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if Self.reservedDirectoryNames.contains(name) { return true }
        let relative = NoteIdentity.id(for: url, vaultURL: rootURL)
        let first = relative.split(separator: "/").first.map(String.init) ?? name
        return Self.reservedDirectoryNames.contains(first)
    }

    public func isNoteFile(_ url: URL) -> Bool {
        NoteLanguage(pathExtension: url.pathExtension) != nil && !isReservedDirectory(url.deletingLastPathComponent())
    }
}

public struct VaultConfigFile: Codable, Equatable, Sendable {
    public var siteTitle: String
    public var siteBaseURL: String
    public var siteAuthor: String
    public var borisBinaryPath: String?
    public var oliverBinaryPath: String?
    public var cloudflareAccountID: String?
    public var cloudflareProjectName: String
    public var cloudflareCustomDomain: String

    public init(
        siteTitle: String = "Notes",
        siteBaseURL: String = "",
        siteAuthor: String = "",
        borisBinaryPath: String? = nil,
        oliverBinaryPath: String? = nil,
        cloudflareAccountID: String? = nil,
        cloudflareProjectName: String = "banal-notes",
        cloudflareCustomDomain: String = ""
    ) {
        self.siteTitle = siteTitle
        self.siteBaseURL = siteBaseURL
        self.siteAuthor = siteAuthor
        self.borisBinaryPath = borisBinaryPath
        self.oliverBinaryPath = oliverBinaryPath
        self.cloudflareAccountID = cloudflareAccountID
        self.cloudflareProjectName = cloudflareProjectName
        self.cloudflareCustomDomain = cloudflareCustomDomain
    }

    public init(from configuration: VaultConfiguration) {
        self.init(
            siteTitle: configuration.siteTitle,
            siteBaseURL: configuration.siteBaseURL,
            siteAuthor: configuration.siteAuthor,
            borisBinaryPath: configuration.borisBinaryPath,
            oliverBinaryPath: configuration.oliverBinaryPath,
            cloudflareAccountID: configuration.cloudflareAccountID,
            cloudflareProjectName: configuration.cloudflareProjectName,
            cloudflareCustomDomain: configuration.cloudflareCustomDomain
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        siteTitle = try container.decodeIfPresent(String.self, forKey: .siteTitle) ?? "Notes"
        siteBaseURL = try container.decodeIfPresent(String.self, forKey: .siteBaseURL) ?? ""
        siteAuthor = try container.decodeIfPresent(String.self, forKey: .siteAuthor) ?? ""
        borisBinaryPath = try container.decodeIfPresent(String.self, forKey: .borisBinaryPath)
        oliverBinaryPath = try container.decodeIfPresent(String.self, forKey: .oliverBinaryPath)
        cloudflareAccountID = try container.decodeIfPresent(String.self, forKey: .cloudflareAccountID)
        cloudflareProjectName = try container.decodeIfPresent(String.self, forKey: .cloudflareProjectName) ?? "banal-notes"
        cloudflareCustomDomain = try container.decodeIfPresent(String.self, forKey: .cloudflareCustomDomain) ?? ""
    }
}

public enum VaultBootstrap {
    public static let welcomeBody = """
    # Welcome to BANAL

    BANAL is a local-first Mac notes app. Everything you write is an ordinary file in this folder — Markdown, Textile, or Cooklang.

    - Press ⌘N to create a note in the selected folder.
    - File → New Textile and File → New Recipe write `.textile` and `.cook` files.
    - Press ⇧⌘N to create a folder.
    - Press ⌘⌫ to move a note or folder to Trash.
    - Drop images into `assets/` and reference them as `![alt](assets/photo.png)`.
    - Flip **Published** on a note, then choose File → Publish Site… when you want a static site.

    External edits in Finder, Vim, or VS Code show up here automatically.
    """

    @discardableResult
    public static func prepare(_ configuration: VaultConfiguration, fileManager: FileManager = .default) throws -> URL {
        try fileManager.createDirectory(at: configuration.rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: configuration.assetsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: configuration.metadataURL, withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: configuration.configURL.path) {
            let payload = VaultConfigFile(from: configuration)
            let data = try JSONEncoder.pretty.encode(payload)
            try data.write(to: configuration.configURL, options: .atomic)
        }

        let notes = try fileManager.contentsOfDirectory(at: configuration.rootURL, includingPropertiesForKeys: nil)
        let hasNote = notes.contains { NoteLanguage(pathExtension: $0.pathExtension) != nil }
        if !hasNote {
            let welcomeURL = configuration.rootURL.appendingPathComponent("Welcome.md")
            let now = Date()
            let document = FrontmatterCodec.serialize(
                frontmatter: Frontmatter(
                    title: "Welcome to BANAL",
                    created: now,
                    updated: now,
                    tags: ["welcome"],
                    published: false
                ),
                body: "\n\(Self.welcomeBody)\n"
            )
            try Data(document.utf8).write(to: welcomeURL, options: .atomic)
        }
        return configuration.rootURL
    }

    public static func load(from rootURL: URL, fileManager: FileManager = .default) -> VaultConfiguration {
        var configuration = VaultConfiguration(rootURL: rootURL)
        let configURL = configuration.configURL
        guard
            let data = fileManager.contents(atPath: configURL.path),
            let file = try? JSONDecoder().decode(VaultConfigFile.self, from: data)
        else {
            return configuration
        }
        configuration.siteTitle = file.siteTitle
        configuration.siteBaseURL = file.siteBaseURL
        configuration.siteAuthor = file.siteAuthor
        configuration.borisBinaryPath = file.borisBinaryPath
        configuration.oliverBinaryPath = file.oliverBinaryPath
        configuration.cloudflareAccountID = file.cloudflareAccountID
        configuration.cloudflareProjectName = file.cloudflareProjectName
        configuration.cloudflareCustomDomain = file.cloudflareCustomDomain
        return configuration
    }

    public static func save(_ configuration: VaultConfiguration, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: configuration.metadataURL, withIntermediateDirectories: true)
        let file = VaultConfigFile(from: configuration)
        let encoded = try JSONEncoder.pretty.encode(file)
        // Yuma: preserve unknown keys that may exist in an existing config.json on disk.
        // Decode both sides as JSON dictionaries, merge old unknowns where new has no value, then re-serialize.
        if let existingData = fileManager.contents(atPath: configuration.configURL.path),
           let existingObj = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any],
           let newObj = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any] {
            var merged = newObj
            for (k, v) in existingObj where merged[k] == nil {
                merged[k] = v
            }
            let mergedData = try JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted, .sortedKeys])
            var out = mergedData
            if out.last != 10 { out.append(10) }
            try out.write(to: configuration.configURL, options: .atomic)
            return
        }
        try encoded.write(to: configuration.configURL, options: .atomic)
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
