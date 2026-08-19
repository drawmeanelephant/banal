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
        if let configured, !configured.isEmpty {
            let url = URL(fileURLWithPath: configured)
            if fileManager.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        if let env = environment["BANAL_OLIVER_BIN"], !env.isEmpty {
            let url = URL(fileURLWithPath: env)
            if fileManager.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        if let found = which("oliver", path: environment["PATH"] ?? "", fileManager: fileManager) {
            return found
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
            let candidate = cwd.appendingPathComponent(relative).standardizedFileURL
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
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

public enum OliverFrontend: String, Sendable {
    case markdown
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

/// One-shot question to Oliver: what HTML is this Markdown?
///
/// Invokes `oliver render --from markdown`. Stdin is the note **body**.
/// BANAL frontmatter is stripped first and `--frontmatter` is never
/// passed, so Oliver cannot reinterpret local keys.
///
/// Call this off the caret path. Use a debounce at the call site —
/// never from `textDidChange`.
public struct OliverClient: Sendable {
    public var binaryURL: URL

    public init(binaryURL: URL) {
        self.binaryURL = binaryURL
    }

    public func render(_ source: String, frontend: OliverFrontend = .markdown) throws -> OliverRender {
        let body = Self.bodyForOliver(source)
        let html = try run(body: body, frontend: frontend)
        return OliverRender(html: html, frontend: frontend)
    }

    /// BANAL owns local metadata. Send only the body.
    public static func bodyForOliver(_ source: String) -> String {
        guard let parsed = try? FrontmatterCodec.parse(source), parsed.hasFrontmatter else {
            return source
        }
        return parsed.body
    }

    private func run(body: String, frontend: OliverFrontend) throws -> String {
        guard FileManager.default.isExecutableFile(atPath: binaryURL.path) else {
            throw OliverError.missingBinary
        }

        let process = Process()
        process.executableURL = binaryURL
        process.arguments = ["render", "--from", frontend.rawValue]

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

    private let render: (@Sendable (String) -> OliverRender?)?
    private let delay: TimeInterval
    private let queue: DispatchQueue
    private var pending: DispatchWorkItem?
    private let lock = NSLock()

    public var isAvailable: Bool { render != nil }

    public init(client: OliverClient?, delay: TimeInterval = OliverDebounce.delay) {
        if let client {
            self.render = { try? client.render($0) }
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
        self.render = render
        self.delay = delay
        self.queue = DispatchQueue(label: "dev.drawmeanelephant.banal.oliver.test", qos: .utility)
    }

    public func schedule(source: String, completion: @escaping @Sendable (OliverRender) -> Void) {
        guard let render else { return }
        lock.lock()
        pending?.cancel()
        let work = DispatchWorkItem {
            guard let result = render(source) else { return }
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
