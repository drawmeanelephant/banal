import Foundation
import BANALCore

public struct PublishConfiguration: Equatable, Sendable {
    public var siteTitle: String
    public var siteBaseURL: String
    public var artifactDirectory: URL
    public var stagingDirectory: URL
    public var borisBinaryURL: URL?
    public var oliverBinaryURL: URL?
    public var preferBoris: Bool
    public var author: String

    public init(
        siteTitle: String = "Notes",
        siteBaseURL: String = "",
        artifactDirectory: URL,
        stagingDirectory: URL,
        borisBinaryURL: URL? = nil,
        oliverBinaryURL: URL? = nil,
        preferBoris: Bool = true,
        author: String = ""
    ) {
        self.siteTitle = siteTitle
        self.siteBaseURL = siteBaseURL
        self.artifactDirectory = artifactDirectory
        self.stagingDirectory = stagingDirectory
        self.borisBinaryURL = borisBinaryURL
        self.oliverBinaryURL = oliverBinaryURL
        self.preferBoris = preferBoris
        self.author = author
    }

    public static func `default`(for vault: VaultConfiguration, fileManager: FileManager = .default) -> PublishConfiguration {
        PublishConfiguration(
            siteTitle: vault.siteTitle,
            siteBaseURL: vault.siteBaseURL,
            artifactDirectory: vault.publishURL,
            stagingDirectory: vault.metadataURL.appendingPathComponent("stage", isDirectory: true),
            borisBinaryURL: BorisLocator.resolve(configured: vault.borisBinaryPath, fileManager: fileManager),
            oliverBinaryURL: OliverLocator.resolve(configured: vault.oliverBinaryPath, fileManager: fileManager)
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

    /// One sentence for the status strip. Grammar matches the count.
    public var statusCopy: String {
        let compiled = compiledNoteIDs.count
        let engine = usedBorisBinary ? "Boris" : "builtin"
        let compiledNoun = compiled == 1 ? "note" : "notes"
        if skipped.isEmpty {
            return "Published \(compiled) \(compiledNoun) with \(engine)."
        }
        let skippedCount = skipped.count
        let noun = skippedCount == 1 ? skipped[0].label : "notes"
        return "Published \(compiled) \(compiledNoun). Skipped \(skippedCount) \(noun)."
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
    /// Finished HTML for a non-Markdown page (Cooklang/Textile rendered by
    /// Oliver). The page is staged as Markdown whose body is this HTML, so a
    /// compiling engine emits it as one of its own outputs; the builtin
    /// compiler pastes it into the theme layout without re-rendering.
    /// CommonMark passes raw HTML blocks through byte-for-byte.
    public var prebuiltBodyHTML: String?

    public init(
        entityID: String,
        relativePath: String,
        source: String,
        title: String,
        tags: [String],
        updated: Date,
        language: NoteLanguage = .markdown,
        prebuiltBodyHTML: String? = nil
    ) {
        self.entityID = entityID
        self.relativePath = relativePath
        self.source = source
        self.title = title
        self.tags = tags
        self.updated = updated
        self.language = language
        self.prebuiltBodyHTML = prebuiltBodyHTML
    }
}

public enum PublishError: Error, Equatable, Sendable {
    case noPublishedNotes
    case nothingCompiled
    case borisFailed(status: Int32, stderr: String)
    case missingBorisBinary
    case io(String)
}

/// Which rung of the engine locator chain answered.
///
/// The chain is ordered by preference (configured → bundled → env → PATH →
/// working dir), and the CLI has one extra rung the app does not: an engine
/// bundled inside an installed BANAL.app. This names which one won, because a
/// bare CLI has no bundle of its own and will happily report an engine from
/// `PATH` while the app it ships beside is using a *different* binary from
/// `Contents/Helpers`. A green report should never quietly conflate the two.
public enum EngineSource: String, Equatable, Sendable, CaseIterable {
    case configured
    case bundled
    case environment
    case path
    case workingDirectory
    case installedApp

    /// Short human label for `doctor` output.
    public var label: String {
        switch self {
        case .configured: return "configured"
        case .bundled: return "bundled"
        case .environment: return "env"
        case .path: return "PATH"
        case .workingDirectory: return "working dir"
        case .installedApp: return "installed app"
        }
    }
}

/// A located engine plus where it came from.
public struct ResolvedEngine: Equatable, Sendable {
    public let url: URL
    public let source: EngineSource

    public init(url: URL, source: EngineSource) {
        self.url = url
        self.source = source
    }
}

public enum BorisLocator {
    /// Order: configured path, the app-bundled helper,
    /// `BANAL_BORIS_BIN`, `PATH`, then a sibling checkout. The bundle
    /// lookup and environment are injectable so tests can prove the
    /// order without a real bundle or machine state.
    public static func resolve(
        configured: String?,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectory: URL? = nil,
        fileManager: FileManager = .default,
        auxiliaryExecutables: (String) -> [URL] = BundledHelper.executables
    ) -> URL? {
        resolveDetailed(
            configured: configured,
            environment: environment,
            currentDirectory: currentDirectory,
            fileManager: fileManager,
            auxiliaryExecutables: auxiliaryExecutables
        )?.url
    }

    /// Same order as `resolve`, but names the rung that answered, so a report
    /// can distinguish "the engine in this bundle" from "whatever is on PATH".
    public static func resolveDetailed(
        configured: String?,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectory: URL? = nil,
        fileManager: FileManager = .default,
        auxiliaryExecutables: (String) -> [URL] = BundledHelper.executables
    ) -> ResolvedEngine? {
        if let configured, !configured.isEmpty {
            let url = URL(fileURLWithPath: configured)
            if fileManager.isExecutableFile(atPath: url.path) {
                return ResolvedEngine(url: url, source: .configured)
            }
        }
        for url in auxiliaryExecutables("boris") where fileManager.isExecutableFile(atPath: url.path) {
            return ResolvedEngine(url: url, source: .bundled)
        }
        if let env = environment["BANAL_BORIS_BIN"], !env.isEmpty {
            let url = URL(fileURLWithPath: env)
            if fileManager.isExecutableFile(atPath: url.path) {
                return ResolvedEngine(url: url, source: .environment)
            }
        }
        if let found = which("boris", path: environment["PATH"] ?? "", fileManager: fileManager) {
            return ResolvedEngine(url: found, source: .path)
        }
        let cwd = currentDirectory ?? URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let relatives = [
            "dist/helpers/boris",
            ".build/helpers/boris",
            ".build/helpers-src/boris/zig-out/bin/boris",
            "zig-out/bin/boris",
            "../boris/zig-out/bin/boris",
            "../../boris/zig-out/bin/boris",
            "../../../boris/zig-out/bin/boris",
            "../../../../boris/zig-out/bin/boris",
            "../boris/main/zig-out/bin/boris",
            "../../boris/main/zig-out/bin/boris",
            "../../../boris/main/zig-out/bin/boris",
            "../../../../boris/main/zig-out/bin/boris",
        ]
        for relative in relatives {
            let candidate = cwd.appendingPathComponent(relative).standardizedFileURL
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return ResolvedEngine(url: candidate, source: .workingDirectory)
            }
        }
        return nil
    }

    private static func which(_ name: String, path: String, fileManager: FileManager) -> URL? {
        for directory in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name)
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
