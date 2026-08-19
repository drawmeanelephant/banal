import Foundation
import BANALCore

/// Locates the `oliver` CLI the same way we locate `boris`.
///
/// Order: configured path, `BANAL_OLIVER_BIN`, `PATH`, then a sibling
/// checkout. Oliver’s tree is `oliver/zig-out/bin/oliver` (no `main/`
/// segment). `oliver/main/…` is also tried in case a checkout uses it.
///
/// `environment` and `currentDirectory` are injectable so tests can
/// prove the order without depending on the machine `PATH`.
public enum OliverLocator {
    public static func resolve(
        configured: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) -> URL? {
        candidates(
            configured: configured,
            environment: environment,
            currentDirectory: currentDirectory,
            fileManager: fileManager
        ).first
    }

    /// First Oliver that can `serialize --from cooklang --json`. Same
    /// search order as `resolve`; skips older binaries that only render.
    public static func resolveRecipeJSON(
        configured: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) -> URL? {
        for url in candidates(
            configured: configured,
            environment: environment,
            currentDirectory: currentDirectory,
            fileManager: fileManager
        ) {
            if (try? OliverClient(binaryURL: url).recipe("Add @salt{}.\n")) != nil {
                return url
            }
        }
        return nil
    }

    private static func candidates(
        configured: String?,
        environment: [String: String],
        currentDirectory: URL?,
        fileManager: FileManager
    ) -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()
        func add(_ url: URL) {
            let path = url.standardizedFileURL.path
            guard fileManager.isExecutableFile(atPath: path), !seen.contains(path) else { return }
            seen.insert(path)
            urls.append(url.standardizedFileURL)
        }
        if let configured, !configured.isEmpty {
            add(URL(fileURLWithPath: configured))
        }
        if let env = environment["BANAL_OLIVER_BIN"], !env.isEmpty {
            add(URL(fileURLWithPath: env))
        }
        if let found = which("oliver", path: environment["PATH"] ?? "", fileManager: fileManager) {
            add(found)
        }
        let cwd = currentDirectory ?? URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let relatives = [
            "zig-out/bin/oliver",
            "../oliver/zig-out/bin/oliver",
            "../../oliver/zig-out/bin/oliver",
            "../../../oliver/zig-out/bin/oliver",
            "../../../../oliver/zig-out/bin/oliver",
            "../oliver/main/zig-out/bin/oliver",
            "../../oliver/main/zig-out/bin/oliver",
            "../../../oliver/main/zig-out/bin/oliver",
            "../../../../oliver/main/zig-out/bin/oliver",
        ]
        for relative in relatives {
            add(cwd.appendingPathComponent(relative))
        }
        return urls
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

public enum OliverFrontend: String, Sendable {
    case markdown
    case textile
    case cooklang

    public init(language: NoteLanguage) {
        switch language {
        case .markdown: self = .markdown
        case .textile: self = .textile
        case .cooklang: self = .cooklang
        }
    }
}

public enum OliverError: Error, Equatable, Sendable {
    case missingBinary
    case failed(status: Int32, stderr: String)
}

public struct OliverRender: Equatable, Sendable {
    public var html: String
    public var frontend: OliverFrontend

    public init(html: String, frontend: OliverFrontend = .markdown) {
        self.html = html
        self.frontend = frontend
    }
}

/// One-shot question to Oliver: what HTML is this buffer, or what
/// Recipe is this `.cook` file?
///
/// Invokes `oliver render --from <markdown|textile|cooklang>`, or
/// `serialize --from cooklang --json` / `scale --from cooklang` for
/// the reading view. The frontend is the file extension, never
/// sniffed from the body. Markdown/Textile stdin is the note **body**
/// (BANAL frontmatter stripped). Cooklang stdin is the recipe source.
/// `--frontmatter` is never passed.
///
/// Call this off the caret path. Use a debounce at the call site —
/// never from `textDidChange`. Scale never writes the file.
public struct OliverClient: Sendable {
    public var binaryURL: URL

    public init(binaryURL: URL) {
        self.binaryURL = binaryURL
    }

    public func render(_ source: String, frontend: OliverFrontend = .markdown) throws -> OliverRender {
        let body = Self.bodyForOliver(source, frontend: frontend)
        let html = try run(body: body, arguments: ["render", "--from", frontend.rawValue])
        return OliverRender(html: html, frontend: frontend)
    }

    /// Typed Recipe for the reading view. Scale is Oliver's, in memory.
    /// The caller's `source` is never rewritten.
    public func recipe(_ source: String, scale: RecipeScale = .one) throws -> OliverRecipe {
        let body = Self.bodyForOliver(source, frontend: .cooklang)
        let scaled: String
        if scale == .one {
            scaled = body
        } else {
            scaled = try run(
                body: body,
                arguments: ["scale", "--from", "cooklang", "--factor", scale.factorArgument]
            )
        }
        let json = try run(
            body: scaled,
            arguments: ["serialize", "--from", "cooklang", "--json"]
        )
        do {
            return try OliverRecipe.decode(from: json)
        } catch {
            throw OliverError.failed(status: 0, stderr: "Oliver did not return a recipe")
        }
    }

    /// Scales a Cooklang source by a percent (150 → `--factor 3/2`). Used
    /// to honor a recipe reference's `{150%g}` before inlining (D-3). In
    /// memory only — never writes the file. 100% is a no-op.
    public func scaleSource(_ source: String, percent: Int) throws -> String {
        guard percent > 0, percent != 100 else { return source }
        return try run(
            body: source,
            arguments: ["scale", "--from", "cooklang", "--factor", Self.fraction(forPercent: percent)]
        )
    }

    /// 150 → "3/2", 50 → "1/2", 200 → "2" — Oliver's `<num[/den]>` scale factor.
    static func fraction(forPercent percent: Int) -> String {
        let divisor = Self.greatestCommonDivisor(percent, 100)
        let numerator = percent / divisor
        let denominator = 100 / divisor
        if denominator == 1 { return "\(numerator)" }
        return "\(numerator)/\(denominator)"
    }

    private static func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        var x = abs(a)
        var y = abs(b)
        while y != 0 {
            (x, y) = (y, x % y)
        }
        return max(x, 1)
    }

    /// BANAL owns local metadata. Send only the body for Markdown/Textile.
    /// Cooklang source is sent whole — BANAL does not strip `---` from recipes.
    public static func bodyForOliver(_ source: String, frontend: OliverFrontend = .markdown) -> String {
        if frontend == .cooklang {
            return source
        }
        guard let parsed = try? FrontmatterCodec.parse(source), parsed.hasFrontmatter else {
            return source
        }
        return parsed.body
    }

    private func run(body: String, arguments: [String]) throws -> String {
        guard FileManager.default.isExecutableFile(atPath: binaryURL.path) else {
            throw OliverError.missingBinary
        }

        let process = Process()
        process.executableURL = binaryURL
        process.arguments = arguments

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        // Read pipes while the process runs so a large HTML fragment
        // cannot fill the pipe and deadlock waitUntilExit.
        let group = DispatchGroup()
        let box = PipeBox()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            box.stdout = stdout.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            box.stderr = stderr.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        do {
            try process.run()
        } catch {
            throw OliverError.missingBinary
        }
        stdin.fileHandleForWriting.write(Data(body.utf8))
        stdin.fileHandleForWriting.closeFile()
        process.waitUntilExit()
        group.wait()

        if process.terminationStatus != 0 {
            let err = String(data: box.stderr, encoding: .utf8) ?? ""
            throw OliverError.failed(status: process.terminationStatus, stderr: err)
        }
        return String(data: box.stdout, encoding: .utf8) ?? ""
    }
}

/// Tiny heap box so the two pipe readers can share collected bytes.
private final class PipeBox: @unchecked Sendable {
    var stdout = Data()
    var stderr = Data()
}

/// Debounces `OliverClient.render` at the call site. Never put this in
/// `textDidChange`. Missing binary is silent.
public final class OliverDebounce: @unchecked Sendable {
    public static let delay: TimeInterval = 0.4

    private let render: (@Sendable (String, OliverFrontend) -> OliverRender?)?
    private let delay: TimeInterval
    private let queue: DispatchQueue
    private var pending: DispatchWorkItem?
    private let lock = NSLock()

    public var isAvailable: Bool { render != nil }

    public init(client: OliverClient?, delay: TimeInterval = OliverDebounce.delay) {
        if let client {
            self.render = { source, frontend in try? client.render(source, frontend: frontend) }
        } else {
            self.render = nil
        }
        self.delay = delay
        self.queue = DispatchQueue(label: "dev.drawmeanelephant.banal.oliver", qos: .utility)
    }

    public convenience init(configured: String? = nil, delay: TimeInterval = OliverDebounce.delay) {
        if let url = OliverLocator.resolve(configured: configured) {
            self.init(client: OliverClient(binaryURL: url), delay: delay)
        } else {
            self.init(client: nil, delay: delay)
        }
    }

    /// Test seam: a render function instead of a process.
    public init(delay: TimeInterval, render: @escaping @Sendable (String) -> OliverRender?) {
        self.render = { source, _ in render(source) }
        self.delay = delay
        self.queue = DispatchQueue(label: "dev.drawmeanelephant.banal.oliver.test", qos: .utility)
    }

    public func schedule(
        source: String,
        frontend: OliverFrontend = .markdown,
        completion: @escaping @Sendable (OliverRender) -> Void
    ) {
        guard let render else { return }
        lock.lock()
        pending?.cancel()
        let work = DispatchWorkItem {
            guard let result = render(source, frontend) else { return }
            completion(result)
        }
        pending = work
        lock.unlock()
        if delay <= 0 {
            queue.async(execute: work)
        } else {
            queue.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    public func cancel() {
        lock.lock()
        pending?.cancel()
        pending = nil
        lock.unlock()
    }

    deinit {
        cancel()
    }
}
