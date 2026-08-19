import Foundation
import BANALCore

public struct PublishConfiguration: Equatable, Sendable {
    public var siteTitle: String
    public var siteBaseURL: String
    public var artifactDirectory: URL
    public var stagingDirectory: URL
    public var borisBinaryURL: URL?
    public var preferBoris: Bool
    public var author: String

    public init(
        siteTitle: String = "Notes",
        siteBaseURL: String = "",
        artifactDirectory: URL,
        stagingDirectory: URL,
        borisBinaryURL: URL? = nil,
        preferBoris: Bool = true,
        author: String = ""
    ) {
        self.siteTitle = siteTitle
        self.siteBaseURL = siteBaseURL
        self.artifactDirectory = artifactDirectory
        self.stagingDirectory = stagingDirectory
        self.borisBinaryURL = borisBinaryURL
        self.preferBoris = preferBoris
        self.author = author
    }

    public static func `default`(for vault: VaultConfiguration, fileManager: FileManager = .default) -> PublishConfiguration {
        PublishConfiguration(
            siteTitle: vault.siteTitle,
            siteBaseURL: vault.siteBaseURL,
            artifactDirectory: vault.publishURL,
            stagingDirectory: vault.metadataURL.appendingPathComponent("stage", isDirectory: true),
            borisBinaryURL: BorisLocator.resolve(configured: vault.borisBinaryPath, fileManager: fileManager)
        )
    }
}

public struct PublishResult: Equatable, Sendable {
    public var artifactDirectory: URL
    public var indexURL: URL
    public var rssURL: URL
    public var pageCount: Int
    public var usedBorisBinary: Bool
    public var compiledNoteIDs: [String]
    public var skipped: [PublishSkip]
    public var compilerName: String

    public init(
        artifactDirectory: URL,
        indexURL: URL,
        rssURL: URL,
        pageCount: Int,
        usedBorisBinary: Bool,
        compiledNoteIDs: [String],
        skipped: [PublishSkip] = [],
        compilerName: String
    ) {
        self.artifactDirectory = artifactDirectory
        self.indexURL = indexURL
        self.rssURL = rssURL
        self.pageCount = pageCount
        self.usedBorisBinary = usedBorisBinary
        self.compiledNoteIDs = compiledNoteIDs
        self.skipped = skipped
        self.compilerName = compilerName
    }
}

public struct PublishSkip: Equatable, Sendable {
    public var noteID: String
    public var language: NoteLanguage

    public init(noteID: String, language: NoteLanguage) {
        self.noteID = noteID
        self.language = language
    }

    public var label: String {
        switch language {
        case .markdown: return "Markdown"
        case .textile: return "Textile"
        case .cooklang: return "recipe"
        }
    }
}

public struct BorisPage: Equatable, Sendable {
    public var entityID: String
    public var relativePath: String
    public var source: String
    public var title: String
    public var tags: [String]
    public var updated: Date
    public var language: NoteLanguage

    public init(
        entityID: String,
        relativePath: String,
        source: String,
        title: String,
        tags: [String],
        updated: Date,
        language: NoteLanguage = .markdown
    ) {
        self.entityID = entityID
        self.relativePath = relativePath
        self.source = source
        self.title = title
        self.tags = tags
        self.updated = updated
        self.language = language
    }
}

public enum PublishError: Error, Equatable, Sendable {
    case noPublishedNotes
    case nothingCompiled
    case borisFailed(status: Int32, stderr: String)
    case missingBorisBinary
    case io(String)
}

public enum BorisLocator {
    public static func resolve(configured: String?, fileManager: FileManager = .default) -> URL? {
        if let configured, !configured.isEmpty {
            let url = URL(fileURLWithPath: configured)
            if fileManager.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        if let env = ProcessInfo.processInfo.environment["BANAL_BORIS_BIN"], !env.isEmpty {
            let url = URL(fileURLWithPath: env)
            if fileManager.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        if let found = which("boris", fileManager: fileManager) {
            return found
        }
        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let relatives = [
            "zig-out/bin/boris",
            "../boris/main/zig-out/bin/boris",
            "../../boris/main/zig-out/bin/boris",
            "../../../boris/main/zig-out/bin/boris",
            "../../../../boris/main/zig-out/bin/boris",
        ]
        for relative in relatives {
            let candidate = cwd.appendingPathComponent(relative).standardizedFileURL
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private static func which(_ name: String, fileManager: FileManager) -> URL? {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name)
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
