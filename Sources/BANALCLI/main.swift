// banal — agent CLI over BANALCore/BANALPublisher.
//
// A verification surface, not a product feature (#204): the same NoteStore,
// the same vault resolution, and the same publish pipeline the app uses,
// reachable without pixels. Read-mostly; the editor remains the app.

import ArgumentParser
import BANALCore
import BANALPublisher
import Foundation

@main
struct BanalCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "banal",
        abstract: "Agent CLI for BANAL notes folders.",
        version: "0.1.0",
        subcommands: [
            Vault.self, Notes.self, Show.self, Doctor.self, Publish.self,
        ]
    )
}

// MARK: - Shared

/// ParsableCommand.run() is nonisolated; every subcommand body is main-actor
/// (the store and publishers are). MainActor.assumeIsolated executes synchronously
/// on the main actor without background hops or error swallowing.
func onMain<T: Sendable>(_ body: @MainActor () throws -> T) rethrows -> T {
    try MainActor.assumeIsolated(body)
}

/// Vault resolution identical to the app: explicit --vault wins, then the
/// app's own resolver (bookmark → ~/Documents/BANAL Notes → error).
struct VaultOptions: ParsableArguments {
    @Option(name: .long, help: "Path to notes folder (default: app's configured vault).")
    var vault: String?
}

@MainActor
func loadStore(_ options: VaultOptions) throws -> NoteStore {
    if let vault = options.vault {
        let url = URL(fileURLWithPath: vault)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            throw ValidationError("vault folder not found: \(vault)")
        }
        let store = NoteStore(configuration: VaultConfiguration(rootURL: url), monitor: nil)
        try store.open()
        return store
    }
    do {
        return try IntentVaultResolver.loadStore()
    } catch IntentVaultError.vaultNotFound {
        throw ValidationError("no notes folder configured — pass --vault or choose one in the app")
    }
}

extension Note {
    var jsonLine: [String: Any] {
        [
            "id": id,
            "title": title,
            "language": language.rawValue,
            "published": published,
            "tags": tags,
            "created": created.ISO8601Format(),
            "updated": updated.ISO8601Format(),
            "bytes": fileSize ?? 0,
        ]
    }
}

func printJSON(_ object: Any) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    guard let text = String(data: data, encoding: .utf8) else {
        throw ValidationError("failed to encode JSON output as UTF-8")
    }
    print(text)
}

// MARK: - Subcommands

extension BanalCLI {
    struct Vault: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print resolved notes folder and note count.",
            discussion: "Omitting --vault follows the app's own resolution (its bookmark). An empty --vault folder is seeded on first open, matching app behavior."
        )

        @OptionGroup var options: VaultOptions
        @Flag(name: .long, help: "Machine-readable JSON output.") var json = false

        mutating func run() throws {
            let vaultOptions = options
            let jsonFlag = json
            try onMain {
                let store = try loadStore(vaultOptions)
                let path = store.configuration.rootURL.path
                if jsonFlag {
                    try printJSON(["vault": path, "notes": store.notes.count])
                } else {
                    print("\(path)  (\(store.notes.count) notes)")
                }
            }
        }
    }

    struct Notes: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List notes in the vault."
        )

        @OptionGroup var options: VaultOptions
        @Flag(name: .long, help: "Machine-readable JSON output.") var json = false
        @Flag(name: .long, help: "Only list published notes.") var published = false

        mutating func run() throws {
            let vaultOptions = options
            let jsonFlag = json
            let publishedFlag = published
            try onMain {
                let store = try loadStore(vaultOptions)
                var notes = store.notes
                if publishedFlag { notes = notes.filter(\.published) }
                if jsonFlag {
                    try printJSON(notes.map(\.jsonLine))
                } else {
                    for n in notes {
                        let flag = n.published ? " [published]" : ""
                        print("\(n.id)\(flag)  —  \(n.displayTitle)")
                    }
                }
            }
        }
    }

    struct Show: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print a note's raw content or parsed metadata."
        )

        @OptionGroup var options: VaultOptions
        @Flag(name: .long, help: "Print parsed note metadata as JSON instead of raw content.") var json = false
        @Argument(help: "Vault-relative note ID (e.g. Recipes/Sunday Sauce.cook).") var id: String

        mutating func run() throws {
            let vaultOptions = options
            let jsonFlag = json
            let noteID = id
            try onMain {
                let store = try loadStore(vaultOptions)
                guard let note = store.note(id: noteID) else {
                    throw ValidationError("no note with id \"\(noteID)\"")
                }
                if jsonFlag {
                    try printJSON(note.jsonLine)
                } else {
                    do {
                        let text = try String(contentsOf: note.fileURL, encoding: .utf8)
                        print(text)
                    } catch {
                        throw ValidationError("could not read \(note.fileURL.path): \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// One line per subsystem; first failing contract check wins.
    struct Doctor: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Vault, toolchain, and publish-contract health check.",
            discussion: """
            Reads the app's own vault when --vault is omitted. An empty --vault folder is seeded like a first app run (Welcome.md).

            Exit codes:
              0   Clean (all checks passed)
             64   Warning (e.g. external compilers missing, builtin compiler used)
              1   Failure (vault/toolchain/contract error)
            """
        )

        @OptionGroup var options: VaultOptions
        @Flag(name: .long, help: "Machine-readable JSON output.") var json = false

        mutating func run() throws {
            let vaultOptions = options
            let jsonFlag = json
            try onMain {
                var rows: [[String: Any]] = []

                let store = try loadStore(vaultOptions)
                rows.append([
                    "check": "vault",
                    "value": store.configuration.rootURL.path,
                    "ok": true,
                    "state": "ok",
                    "detail": "\(store.notes.count) notes",
                ])

                func toolRow(_ name: String, configured: String?, locator: (String?) -> URL?) {
                    if let url = locator(configured) {
                        rows.append([
                            "check": name,
                            "value": url.path,
                            "ok": true,
                            "state": "ok",
                            "detail": "discovered",
                        ])
                    } else if let configured, !configured.isEmpty {
                        rows.append([
                            "check": name,
                            "value": configured,
                            "ok": false,
                            "state": "fail",
                            "detail": "configured but not executable",
                        ])
                    } else {
                        // Absent + unconfigured is a healthy config: the builtin
                        // compiler covers it. Warn, don't fail.
                        rows.append([
                            "check": name,
                            "value": "",
                            "ok": true,
                            "state": "warn",
                            "detail": "not found — builtin compiler will be used",
                        ])
                    }
                }
                toolRow("boris", configured: store.configuration.borisBinaryPath,
                        locator: { BorisLocator.resolve(configured: $0) })
                toolRow("oliver", configured: store.configuration.oliverBinaryPath,
                        locator: { OliverLocator.resolve(configured: $0) })

                // Publish-boundary contract: staged entity ids must satisfy Boris's
                // identity contract even when the builtin compiler is in play —
                // otherwise the site passes here and fails on any boris machine (#202).
                let published = BorisAdapter.publishedNotes(from: store.notes)
                var contract: [String: Any] = [
                    "check": "contract",
                    "value": "publish-boundary",
                    "ok": true,
                    "state": "ok",
                    "detail": "ok",
                ]
                if !published.isEmpty {
                    let ids = published.map { BorisAdapter.entityID(for: $0, among: published) }
                    let bad = zip(published, ids).first { _, id in !Self.borisConforming(id) }
                    if let (note, id) = bad {
                        contract["ok"] = false
                        contract["state"] = "fail"
                        contract["detail"] = "\"\(note.id)\" stages as \"\(id)\" — Boris rejects it (see #202/#203)"
                    }
                } else {
                    contract["detail"] = "no published notes"
                }
                rows.append(contract)

                let failed = rows.contains { !($0["ok"] as? Bool ?? true) }
                let warned = rows.contains { ($0["state"] as? String) == "warn" }
                if jsonFlag {
                    try printJSON(rows)
                } else {
                    for row in rows {
                        let ok = row["ok"] as? Bool ?? false
                        let state = row["state"] as? String
                        let mark = !ok ? "FAIL" : (state == "warn" ? "warn" : "ok  ")
                        let value = row["value"] as? String ?? ""
                        let truncated = value.count > 36 ? "…" + value.suffix(35) : value
                        let padded = truncated.padding(toLength: 36, withPad: " ", startingAt: 0)
                        let name = (row["check"] as? String ?? "?").padding(toLength: 9, withPad: " ", startingAt: 0)
                        print("\(name) \(padded) \(mark)  \(row["detail"] ?? "")")
                    }
                }
                if failed { throw ExitCode.failure }
                if warned { throw ExitCode(64) }
            }
        }

        /// Mirrors Boris's identity contract (docs/contracts/identity-and-paths.md
        /// rule 2): no whitespace, no `# ? % \\`, no empty/./.. segments, ≤255 bytes.
        static func borisConforming(_ id: String) -> Bool {
            guard !id.isEmpty, id.utf8.count <= 255 else { return false }
            for seg in id.split(separator: "/", omittingEmptySubsequences: false) {
                if seg.isEmpty || seg == "." || seg == ".." { return false }
                for ch in seg where ch.isWhitespace || ch == "#" || ch == "?" || ch == "%" || ch == "\\" {
                    return false
                }
            }
            return true
        }
    }

    struct Publish: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Run the publish pipeline for a vault.",
            discussion: "Renders published notes to HTML and RSS using Boris/Oliver or the builtin compiler."
        )

        @OptionGroup var options: VaultOptions

        mutating func run() throws {
            let vaultOptions = options
            try onMain {
                let store = try loadStore(vaultOptions)
                let vault = store.configuration
                _ = CompilerBookmark.access(path: vault.borisBinaryPath, name: "boris")
                _ = CompilerBookmark.access(path: vault.oliverBinaryPath, name: "oliver")
                let configuration = PublishConfiguration.default(for: vault)
                let result = try BANALPublisher.make(configuration: configuration).publish(
                    notes: store.notes, vault: vault, configuration: configuration
                )
                print(result.statusCopy)
            }
        }
    }
}
