import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device text enrichment: improve Markdown markup or suggest a title.
///
/// Silent if absent. Never auto. Undo at the call site.
public protocol EnrichmentClient: Sendable {
    /// Improve the Markdown formatting of `source`. Returns nil if unavailable.
    func enrichMarkup(_ source: String) async throws -> String?
    /// Suggest a title for `source`. Returns nil if unavailable.
    func suggestTitle(_ source: String) async throws -> String?
}

// MARK: - Foundation Models (macOS 26+)

/// Uses Apple's on-device Foundation Models framework when available.
/// Falls back to nil (silent) on older macOS.
public struct FoundationModelsEnricher: EnrichmentClient {
    public init() {}

    public func enrichMarkup(_ source: String) async throws -> String? {
        guard #available(macOS 26.0, *) else { return nil }
        return try await FoundationModelsSession.enrich(source, task: .enrichMarkup)
    }

    public func suggestTitle(_ source: String) async throws -> String? {
        guard #available(macOS 26.0, *) else { return nil }
        return try await FoundationModelsSession.enrich(source, task: .suggestTitle)
    }
}

// MARK: - User Binary on PATH

/// Calls a user-specified binary for enrichment. The binary receives the
/// source on stdin and must return the result on stdout.
///
/// Expected binary behavior:
/// - `enrich-markup` — stdin: source, stdout: enriched Markdown
/// - `suggest-title` — stdin: source, stdout: suggested title (one line)
public struct BinaryEnricher: EnrichmentClient {
    public var enrichBinaryPath: String?
    public var suggestTitleBinaryPath: String?

    public init(enrichBinaryPath: String? = nil, suggestTitleBinaryPath: String? = nil) {
        self.enrichBinaryPath = enrichBinaryPath
        self.suggestTitleBinaryPath = suggestTitleBinaryPath
    }

    public func enrichMarkup(_ source: String) async throws -> String? {
        guard let path = enrichBinaryPath else { return nil }
        return try runBinary(path, input: source)
    }

    public func suggestTitle(_ source: String) async throws -> String? {
        guard let path = suggestTitleBinaryPath else { return nil }
        return try runBinary(path, input: source)
    }

    private func runBinary(_ path: String, input: String) throws -> String? {
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        stdin.fileHandleForWriting.write(Data(input.utf8))
        stdin.fileHandleForWriting.closeFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let result = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let result, !result.isEmpty else { return nil }
        return result
    }
}

// MARK: - Composite (tries Foundation Models first, then binary)

/// Tries Foundation Models first, falls back to binary.
public struct CompositeEnricher: EnrichmentClient {
    private let foundation: FoundationModelsEnricher
    private let binary: BinaryEnricher

    public init(binaryEnrichPath: String? = nil, binaryTitlePath: String? = nil) {
        self.foundation = FoundationModelsEnricher()
        self.binary = BinaryEnricher(
            enrichBinaryPath: binaryEnrichPath,
            suggestTitleBinaryPath: binaryTitlePath
        )
    }

    public func enrichMarkup(_ source: String) async throws -> String? {
        if let result = try await foundation.enrichMarkup(source) { return result }
        return try await binary.enrichMarkup(source)
    }

    public func suggestTitle(_ source: String) async throws -> String? {
        if let result = try await foundation.suggestTitle(source) { return result }
        return try await binary.suggestTitle(source)
    }
}

// MARK: - Foundation Models Session (macOS 26+)

#if canImport(FoundationModels)
@available(macOS 26.0, *)
private enum FoundationModelsSession {
    enum Task {
        case enrichMarkup
        case suggestTitle
    }

    static func enrich(_ source: String, task: Task) async throws -> String? {
        let prompt: String
        switch task {
        case .enrichMarkup:
            prompt = """
            Improve the Markdown formatting of this text. Fix heading levels, \
            add emphasis where appropriate, clean up list formatting, and \
            ensure proper paragraph spacing. Do not change the content or \
            meaning. Return only the improved Markdown, no explanation.

            \(source)
            """
        case .suggestTitle:
            prompt = """
            Suggest a concise, descriptive title for this text. Return only \
            the title, no quotes, no explanation, no markdown.

            \(source)
            """
        }

        let session = try LanguageModelSession()
        let response = try await session.respond(to: prompt)
        let text = response.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
#endif
