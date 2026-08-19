import Foundation
import BANALCore

public struct SiteCompileResult: Equatable, Sendable {
    public var usedBorisBinary: Bool
    public var compilerName: String
    public init(usedBorisBinary: Bool, compilerName: String) {
        self.usedBorisBinary = usedBorisBinary
        self.compilerName = compilerName
    }
}

public protocol SiteCompiling: Sendable {
    func compile(
        stagingDirectory: URL,
        artifactDirectory: URL,
        pages: [BorisPage],
        configuration: PublishConfiguration
    ) throws -> SiteCompileResult
}

/// Always-available compiler. Emits HTML + copies staged assets. Used when
/// Boris is not installed, and as the test double for SSG shape.
public struct BuiltinSiteCompiler: SiteCompiling {
    public init() {}

    public func compile(
        stagingDirectory: URL,
        artifactDirectory: URL,
        pages: [BorisPage],
        configuration: PublishConfiguration
    ) throws -> SiteCompileResult {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: artifactDirectory.path) {
            try fileManager.removeItem(at: artifactDirectory)
        }
        try fileManager.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)

        for page in pages where page.language == .markdown {
            let rendered = SiteHTML.document(page: page, pages: pages, configuration: configuration)
            let destination = artifactDirectory.appendingPathComponent("\(page.entityID).html")
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(rendered.utf8).write(to: destination, options: .atomic)
        }

        let stagedAssets = stagingDirectory.appendingPathComponent("assets", isDirectory: true)
        if fileManager.fileExists(atPath: stagedAssets.path) {
            try fileManager.copyItem(at: stagedAssets, to: artifactDirectory.appendingPathComponent("assets", isDirectory: true))
        }

        return SiteCompileResult(usedBorisBinary: false, compilerName: "builtin")
    }

}

public enum SiteHTML {
    public static func document(page: BorisPage, pages: [BorisPage], configuration: PublishConfiguration, bodyHTML: String? = nil) -> String {
        let navItems = pages.map { item in
            let current = item.entityID == page.entityID ? " class=\"is-current\"" : ""
            let href = href(from: page.entityID, to: item.entityID)
            return "<li\(current)><a href=\"\(href)\">\(MarkdownHTML.escape(item.title))</a></li>"
        }.joined(separator: "\n")
        let nav = "<nav><ul>\(navItems)</ul></nav>"
        let body = bodyHTML ?? MarkdownHTML.render(stripLeadingNewlines(pageBody(page.source)))
        return BundledTheme.mainLayout
            .replacingOccurrences(of: "{{title}}", with: MarkdownHTML.escape(page.title))
            .replacingOccurrences(of: "{{nav}}", with: nav)
            .replacingOccurrences(of: "{{content}}", with: body)
    }

    /// Relative `href` so a page in `Recipes/` can open `index.html` from Finder.
    public static func href(from sourceEntityID: String, to destinationEntityID: String) -> String {
        let sourceDir = (sourceEntityID as NSString).deletingLastPathComponent
        let sourceParts = sourceDir.split(separator: "/").map(String.init).filter { !$0.isEmpty && $0 != "." }
        let destParts = (destinationEntityID + ".html").split(separator: "/").map(String.init).filter { !$0.isEmpty }
        var common = 0
        while common < sourceParts.count, common + 1 < destParts.count, sourceParts[common] == destParts[common] {
            common += 1
        }
        var bits = Array(repeating: "..", count: sourceParts.count - common)
        bits.append(contentsOf: destParts.dropFirst(common))
        return bits.joined(separator: "/")
    }

    public static func write(_ html: String, entityID: String, artifactDirectory: URL, fileManager: FileManager = .default) throws {
        let destination = artifactDirectory.appendingPathComponent("\(entityID).html")
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(html.utf8).write(to: destination, options: .atomic)
    }

    private static func pageBody(_ source: String) -> String {
        (try? FrontmatterCodec.parse(source))?.body ?? source
    }

    private static func stripLeadingNewlines(_ text: String) -> String {
        String(text.drop(while: { $0 == "\n" || $0 == "\r" }))
    }
}

/// Invokes the Boris CLI: `boris --input content --html-dir <out> --html-layout layouts/main.html --quiet`
public struct BorisCLICompiler: SiteCompiling {
    public var binaryURL: URL
    public var fallback: BuiltinSiteCompiler

    public init(binaryURL: URL, fallback: BuiltinSiteCompiler = BuiltinSiteCompiler()) {
        self.binaryURL = binaryURL
        self.fallback = fallback
    }

    public func compile(
        stagingDirectory: URL,
        artifactDirectory: URL,
        pages: [BorisPage],
        configuration: PublishConfiguration
    ) throws -> SiteCompileResult {
        let fileManager = FileManager.default
        // Boris rejects absolute --html-dir as WorkspaceEscape. Compile into a
        // staging-relative dist/, then copy out to the vault artifact directory.
        let relativeDist = stagingDirectory.appendingPathComponent("dist", isDirectory: true)
        if fileManager.fileExists(atPath: relativeDist.path) {
            try fileManager.removeItem(at: relativeDist)
        }

        let process = Process()
        process.executableURL = binaryURL
        process.currentDirectoryURL = stagingDirectory
        process.arguments = [
            "--input", "content",
            "--html-dir", "dist",
            "--html-layout", "layouts/main.html",
        ]
        let stderr = Pipe()
        let stdout = Pipe()
        process.standardError = stderr
        process.standardOutput = stdout
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return try fallback.compile(
                stagingDirectory: stagingDirectory,
                artifactDirectory: artifactDirectory,
                pages: pages,
                configuration: configuration
            )
        }

        if process.terminationStatus != 0 {
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw PublishError.borisFailed(status: process.terminationStatus, stderr: [err, out].filter { !$0.isEmpty }.joined(separator: "\n"))
        }

        if fileManager.fileExists(atPath: artifactDirectory.path) {
            try fileManager.removeItem(at: artifactDirectory)
        }
        try fileManager.copyItem(at: relativeDist, to: artifactDirectory)

        let stagedAssets = stagingDirectory.appendingPathComponent("assets", isDirectory: true)
        let destAssets = artifactDirectory.appendingPathComponent("assets", isDirectory: true)
        if fileManager.fileExists(atPath: stagedAssets.path), !fileManager.fileExists(atPath: destAssets.path) {
            try fileManager.copyItem(at: stagedAssets, to: destAssets)
        }

        return SiteCompileResult(usedBorisBinary: true, compilerName: "boris")
    }
}
