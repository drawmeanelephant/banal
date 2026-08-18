import Foundation

/// Filesystem layout of a BANAL vault. Disk is the source of truth.
///
/// ```
/// <vault>/
///   Welcome.md
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
    public var cloudflareAccountID: String?
    public var cloudflareProjectName: String
    public var cloudflareCustomDomain: String

    public init(
        rootURL: URL,
        siteTitle: String = "Notes",
        siteBaseURL: String = "",
        siteAuthor: String = "",
        borisBinaryPath: String? = nil,
        cloudflareAccountID: String? = nil,
        cloudflareProjectName: String = "banal-notes",
        cloudflareCustomDomain: String = ""
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.siteTitle = siteTitle
        self.siteBaseURL = siteBaseURL
        self.siteAuthor = siteAuthor
        self.borisBinaryPath = borisBinaryPath
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
        url.pathExtension.lowercased() == "md" && !isReservedDirectory(url.deletingLastPathComponent())
    }
}

public struct VaultConfigFile: Codable, Equatable, Sendable {
    public var siteTitle: String
    public var siteBaseURL: String
    public var siteAuthor: String
    public var borisBinaryPath: String?
    public var cloudflareAccountID: String?
    public var cloudflareProjectName: String
    public var cloudflareCustomDomain: String

    public init(
        siteTitle: String = "Notes",
        siteBaseURL: String = "",
        siteAuthor: String = "",
        borisBinaryPath: String? = nil,
        cloudflareAccountID: String? = nil,
        cloudflareProjectName: String = "banal-notes",
        cloudflareCustomDomain: String = ""
    ) {
        self.siteTitle = siteTitle
        self.siteBaseURL = siteBaseURL
        self.siteAuthor = siteAuthor
        self.borisBinaryPath = borisBinaryPath
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
        cloudflareAccountID = try container.decodeIfPresent(String.self, forKey: .cloudflareAccountID)
        cloudflareProjectName = try container.decodeIfPresent(String.self, forKey: .cloudflareProjectName) ?? "banal-notes"
        cloudflareCustomDomain = try container.decodeIfPresent(String.self, forKey: .cloudflareCustomDomain) ?? ""
    }
}

public enum VaultBootstrap {
    public static let welcomeBody = """
    # Welcome to BANAL

    BANAL is a local-first Mac notes app. Everything you write is an ordinary Markdown file in this folder.

    - Press ⌘N to create a note in the selected folder.
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
        let hasNote = notes.contains { $0.pathExtension.lowercased() == "md" }
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
        configuration.cloudflareAccountID = file.cloudflareAccountID
        configuration.cloudflareProjectName = file.cloudflareProjectName
        configuration.cloudflareCustomDomain = file.cloudflareCustomDomain
        return configuration
    }

    public static func save(_ configuration: VaultConfiguration, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: configuration.metadataURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.pretty.encode(VaultConfigFile(from: configuration))
        try data.write(to: configuration.configURL, options: .atomic)
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
