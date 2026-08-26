import Foundation
import BANALCore
import BANALPublisher

/// Thin read-mostly CLI over BANALCore/BANALPublisher (#204).
///
/// A verification surface for agents, tests, and scripts: the same vault
/// resolution, the same `NoteStore`, and the same publish pipeline as the app,
/// with no pixels. Deliberately not an editor — creating, changing, and filing
/// notes stays in the GUI.
public enum BanalCLI {
    public static let usage = """
    banal — read-mostly window into a BANAL vault

    USAGE
      banal vault [--vault DIR] [--json]     resolved vault + note count
      banal notes [--vault DIR] [--json] [--published]
                                            id, title, language, published, tags, updated
      banal show <id> [--vault DIR] [--json] note file to stdout; --json parses it
      banal publish [--vault DIR] [--json]   run the real publish pipeline
      banal doctor [--vault DIR] [--json]    vault, engines, Boris identity contract

    FLAGS
      --vault DIR   operate on DIR instead of the app's resolved notes folder
      --json        machine-readable output
      -h, --help    this text

    EXIT CODES
      0 ok   64 ran with warnings (degraded but working)   1 operation failed   2 usage error

    The editor is the app. This CLI does not create or change notes;
    `publish` writes only the disposable `.banal/stage` and `.publish` trees.
    """

    struct Invocation {
        var command = ""
        var positional: [String] = []
        var json = false
        var publishedOnly = false
        var vaultPath: String?
        var help = false
    }

    struct ParseError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func parse(_ arguments: [String]) throws -> Invocation {
        var invocation = Invocation()
        var seenCommand = false
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-h", "--help":
                invocation.help = true
            case "--json":
                invocation.json = true
            case "--published":
                invocation.publishedOnly = true
            case "--vault":
                let next = index + 1
                guard next < arguments.count else { throw ParseError(message: "--vault needs a directory") }
                invocation.vaultPath = arguments[next]
                index = next
            default:
                if argument.hasPrefix("-") {
                    throw ParseError(message: "unknown flag \(argument)")
                }
                if seenCommand {
                    invocation.positional.append(argument)
                } else {
                    invocation.command = argument
                    seenCommand = true
                }
            }
            index += 1
        }
        if !seenCommand && !invocation.help {
            throw ParseError(message: "missing command")
        }
        return invocation
    }

    @discardableResult
    public static func run(
        _ arguments: [String],
        out: (String) -> Void,
        err: (String) -> Void
    ) -> Int32 {
        let invocation: Invocation
        do {
            invocation = try parse(arguments)
        } catch {
            err("banal: \(message(for: error))\n")
            err(Self.usage + "\n")
            return 2
        }

        if invocation.help || invocation.command.isEmpty {
            printUsage(out)
            return 0
        }

        do {
            return try execute(invocation, out: out, err: err)
        } catch let failure as CLIFailure {
            err("banal: \(failure.message)\n")
            return 1
        } catch {
            err("banal: \(message(for: error))\n")
            return 1
        }
    }

    /// PublishError cases get real sentences; the default `localizedDescription`
    /// hides which case fired.
    private static func message(for error: Error) -> String {
        switch error as? PublishError {
        case .noPublishedNotes:
            return "Nothing published — mark a note Published first."
        case .nothingCompiled:
            return "Nothing compiled — no published note could be rendered."
        case .borisFailed(let status, let stderr):
            return "boris failed (status \(status)): \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .missingBorisBinary:
            return "The configured Boris binary is missing."
        case .io(let detail):
            return detail
        case nil:
            return error.localizedDescription
        }
    }

    private static func printUsage(_ sink: (String) -> Void) {
        sink(Self.usage + "\n")
    }

    // MARK: - Commands

    private static func execute(_ invocation: Invocation, out: (String) -> Void, err: (String) -> Void) throws -> Int32 {
        switch invocation.command {
        case "vault": return try vault(invocation, out: out)
        case "notes": return try notes(invocation, out: out)
        case "show": return try show(invocation, out: out)
        case "publish": return try publish(invocation, out: out)
        case "doctor": return try doctor(invocation, out: out)
        default:
            err("banal: unknown command \(invocation.command)\n")
            return 2
        }
    }

    private static func vault(_ invocation: Invocation, out: (String) -> Void) throws -> Int32 {
        let configuration = try resolveVault(invocation.vaultPath)
        let count = try MainActor.assumeIsolated {
            try openStore(configuration).notes.count
        }
        if invocation.json {
            out(json(VaultSummary(path: configuration.rootURL.path, noteCount: count)))
        } else {
            out("\(configuration.rootURL.path) (\(count) \(count == 1 ? "note" : "notes"))\n")
        }
        return 0
    }

    private static func notes(_ invocation: Invocation, out: (String) -> Void) throws -> Int32 {
        var storeNotes = try MainActor.assumeIsolated { () -> [Note] in
            try openStore(resolveVault(invocation.vaultPath)).notes
                .sorted { $0.updated > $1.updated }
        }
        if invocation.publishedOnly {
            storeNotes = storeNotes.filter(\.published)
        }
        if invocation.json {
            out(json(storeNotes.map(NoteSummary.init)))
        } else {
            for note in storeNotes {
                let marker = note.published ? "p" : "-"
                let day = DayStamp.string(from: note.updated)
                let language = note.language.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)
                out("\(marker)  \(day)  \(language) \(note.id)\n")
            }
        }
        return 0
    }

    private static func show(_ invocation: Invocation, out: (String) -> Void) throws -> Int32 {
        guard let id = invocation.positional.first else {
            throw CLIFailure("show needs a note id — try `banal notes --json` first")
        }
        let configuration = try resolveVault(invocation.vaultPath)
        let url = try noteURL(for: id, in: configuration)

        if invocation.json {
            let note = try MainActor.assumeIsolated {
                try NoteIO.load(url: url, vaultURL: configuration.rootURL)
            }
            out(json(NoteSummary(note)))
        } else {
            let raw = try String(contentsOf: url, encoding: .utf8)
            out(raw.hasSuffix("\n") ? raw : raw + "\n")
        }
        return 0
    }

    private static func publish(_ invocation: Invocation, out: (String) -> Void) throws -> Int32 {
        let configuration = try resolveVault(invocation.vaultPath)
        // Refresh security-scoped access to configured engines — the same
        // courtesy the app extends before publishing.
        _ = CompilerBookmark.access(path: configuration.borisBinaryPath, name: "boris")
        _ = CompilerBookmark.access(path: configuration.oliverBinaryPath, name: "oliver")
        let publishConfiguration = PublishConfiguration.default(for: configuration)
        let publisher = BANALPublisher.make(configuration: publishConfiguration)
        let result = try MainActor.assumeIsolated { () -> PublishResult in
            let store = try openStore(configuration)
            defer { store.flush() }
            return try publisher.publish(
                notes: store.notes,
                vault: configuration,
                configuration: publishConfiguration
            )
        }
        if invocation.json {
            out(json(PublishSummary(
                statusCopy: result.statusCopy,
                artifactDirectory: result.artifactDirectory.path,
                indexURL: result.indexURL.path,
                rssURL: result.rssURL.path,
                pageCount: result.pageCount,
                usedBorisBinary: result.usedBorisBinary,
                compilerName: result.compilerName,
                compiledNoteIDs: result.compiledNoteIDs,
                skipped: result.skipped.map { SkipSummary(noteID: $0.noteID, language: $0.language.rawValue) }
            )))
        } else {
            out(result.statusCopy + "\n")
            out(result.artifactDirectory.path + "\n")
        }
        return 0
    }

    private static func doctor(_ invocation: Invocation, out: (String) -> Void) throws -> Int32 {
        var checks: [DoctorCheck] = []

        do {
            let configuration = try resolveVault(invocation.vaultPath)
            let snapshot = try MainActor.assumeIsolated { () -> (count: Int, published: [Note], entities: [String: String]) in
                let store = try openStore(configuration)
                let published = BorisAdapter.publishedNotes(from: store.notes)
                return (store.notes.count, published, BorisAdapter.entityIDs(for: published))
            }
            checks.append(DoctorCheck(name: "vault", status: "ok", detail: "\(configuration.rootURL.path) (\(snapshot.count) notes)"))

            // A configured-but-broken engine is a config error; an engine that
            // was never configured is a healthy choice of the builtin path.
            // The CLI speaks for the machine, not one bundle: after the locator
            // (configured → this-bundle → env → PATH → sibling), an installed
            // BANAL.app's bundled engines are the last word before "warn".
            checks.append(binaryCheck(name: "boris", configured: configuration.borisBinaryPath, resolve: { Self.resolveEngine(BorisLocator.resolve(configured: $0), helper: "boris") }, fallback: "builtin HTML will be used"))
            checks.append(binaryCheck(name: "oliver", configured: configuration.oliverBinaryPath, resolve: { Self.resolveEngine(OliverLocator.resolve(configured: $0), helper: "oliver") }, fallback: "recipes stay source when published"))

            if let offender = snapshot.entities.first(where: { !BorisIdentity.isValid($1) }) {
                checks.append(DoctorCheck(name: "contract", status: "fail", detail: "note \(offender.key) maps to invalid entity id \"\(offender.value)\""))
            } else {
                checks.append(DoctorCheck(name: "contract", status: "ok", detail: "\(snapshot.published.count) published ids satisfy the Boris identity contract"))
            }
        } catch {
            checks.append(DoctorCheck(name: "vault", status: "fail", detail: error.localizedDescription))
        }

        let failed = checks.contains { $0.status == "fail" }
        let warned = checks.contains { $0.status == "warn" }
        if invocation.json {
            out(json(DoctorReport(ok: !failed, checks: checks)))
        } else {
            for check in checks {
                let name = check.name.padding(toLength: 10, withPad: " ", startingAt: 0)
                let status = check.status.padding(toLength: 6, withPad: " ", startingAt: 0)
                out("\(name)\(status)\(check.detail)\n")
            }
        }
        // 0 clean · 64 degraded but working (a warning) · 1 broken.
        return failed ? 1 : (warned ? 64 : 0)
    }

    // MARK: - Pieces

    private static func binaryCheck(
        name: String,
        configured: String?,
        resolve: (String?) -> URL?,
        fallback: String
    ) -> DoctorCheck {
        if let configured, !configured.isEmpty {
            let url = URL(fileURLWithPath: configured)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return DoctorCheck(name: name, status: "ok", detail: url.path)
            }
            return DoctorCheck(name: name, status: "fail", detail: "configured at \"\(configured)\" but not executable")
        }
        if let url = resolve(nil) {
            return DoctorCheck(name: name, status: "ok", detail: url.path)
        }
        return DoctorCheck(name: name, status: "warn", detail: "not found — \(fallback)")
    }

    /// Locator result, else the first executable engine inside an installed
    /// BANAL.app (`~/Applications`, then `/Applications`). Machine-global by
    /// nature, so only the CLI — which has no bundle of its own — consults it.
    private static func resolveEngine(_ located: URL?, helper: String) -> URL? {
        if let located { return located }
        return BundledHelper.installedAppHelperURLs(named: helper).first {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
    }

    private static func resolveVault(_ explicit: String?) throws -> VaultConfiguration {
        let root: URL
        if let explicit {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: explicit, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw CLIFailure("no folder at \(explicit)")
            }
            root = URL(fileURLWithPath: explicit, isDirectory: true)
        } else {
            root = try MainActor.assumeIsolated {
                try IntentVaultResolver.resolveVaultURL()
            }
        }
        return VaultBootstrap.load(from: root)
    }

    @MainActor
    private static func openStore(_ configuration: VaultConfiguration) throws -> NoteStore {
        let store = NoteStore(configuration: configuration, monitor: nil)
        try store.open()
        return store
    }

    private static func noteURL(for id: String, in configuration: VaultConfiguration) throws -> URL {
        guard NoteLanguage(pathExtension: (id as NSString).pathExtension) != nil else {
            throw CLIFailure("\"\(id)\" has no .md/.textile/.cook extension")
        }
        guard !id.hasPrefix("/") else {
            throw CLIFailure("note id must stay inside the vault")
        }
        let root = configuration.rootURL.standardizedFileURL.path
        let candidate = configuration.rootURL.appendingPathComponent(id).standardizedFileURL
        guard candidate.path.hasPrefix(root + "/") else {
            throw CLIFailure("note id must stay inside the vault")
        }
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw CLIFailure("no note \"\(id)\" in \(root)")
        }
        return candidate
    }

    private static func json<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}

struct CLIFailure: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) {
        self.message = message
    }
}

// MARK: - Output models

struct VaultSummary: Encodable {
    var path: String
    var noteCount: Int
}

struct NoteSummary: Encodable {
    var id: String
    var title: String
    var folder: String?
    var language: String
    var published: Bool
    var tags: [String]
    var created: Date
    var updated: Date
    var bytes: Int
    var body: String

    init(_ note: Note) {
        id = note.id
        title = note.displayTitle
        folder = note.folder
        language = note.language.rawValue
        published = note.published
        tags = note.tags
        created = note.created
        updated = note.updated
        bytes = note.fileSize ?? 0
        body = note.body
    }
}

struct PublishSummary: Encodable {
    var statusCopy: String
    var artifactDirectory: String
    var indexURL: String
    var rssURL: String
    var pageCount: Int
    var usedBorisBinary: Bool
    var compilerName: String
    var compiledNoteIDs: [String]
    var skipped: [SkipSummary]
}

struct SkipSummary: Encodable {
    var noteID: String
    var language: String
}

struct DoctorCheck: Codable {
    var name: String
    var status: String
    var detail: String
}

struct DoctorReport: Codable {
    var ok: Bool
    var checks: [DoctorCheck]
}
