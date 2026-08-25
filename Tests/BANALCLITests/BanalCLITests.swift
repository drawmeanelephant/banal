import XCTest
@testable import BANALCore
@testable import BANALCLI

final class BanalCLITests: XCTestCase {
    private var vaultURL: URL!
    private var publishedURL: URL!

    override func setUpWithError() throws {
        vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("banal-cli-tests-\(UUID().uuidString)", isDirectory: true)
        try VaultBootstrap.prepare(VaultConfiguration(rootURL: vaultURL))
        let document = FrontmatterCodec.serialize(
            frontmatter: Frontmatter(
                title: "Published Note",
                created: Date(timeIntervalSince1970: 1_770_000_000),
                updated: Date(timeIntervalSince1970: 1_770_000_100),
                tags: ["demo"],
                published: true
            ),
            body: "\nHello from the CLI.\n"
        )
        publishedURL = vaultURL.appendingPathComponent("Published Note.md")
        try Data(document.utf8).write(to: publishedURL)
        let draft = FrontmatterCodec.serialize(
            frontmatter: Frontmatter(title: "Draft", created: Date(), updated: Date(), tags: [], published: false),
            body: "\nNot published.\n"
        )
        try Data(draft.utf8).write(to: vaultURL.appendingPathComponent("Draft.md"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: vaultURL)
        setenv("BANAL_BORIS_BIN", "", 1)
    }

    private func invoke(_ arguments: String...) -> (code: Int32, out: String, err: String) {
        var output = ""
        var errors = ""
        let code = BanalCLI.run(arguments, out: { output += $0 }, err: { errors += $0 })
        return (code, output, errors)
    }

    // MARK: - Usage

    func testMissingCommandIsAUsageError() {
        let result = invoke()
        XCTAssertEqual(result.code, 2)
        XCTAssertTrue(result.err.contains("missing command"), result.err)
        XCTAssertTrue(result.err.contains("USAGE"))
    }

    func testUnknownFlagIsAUsageError() {
        XCTAssertEqual(invoke("notes", "--bogus").code, 2)
    }

    func testHelpExitsCleanly() {
        let result = invoke("--help")
        XCTAssertEqual(result.code, 0)
        XCTAssertTrue(result.out.contains("banal doctor"), result.out)
    }

    // MARK: - vault

    func testVaultReportsResolvedFolderAndCount() throws {
        let result = invoke("vault", "--vault", vaultURL.path, "--json")
        XCTAssertEqual(result.code, 0)
        let data = try XCTUnwrap(result.out.data(using: .utf8))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["noteCount"] as? Int, 3) // Welcome + published + draft
        XCTAssertEqual((object["path"] as? String)?.hasSuffix("Documents"), false)
    }

    func testVaultRejectsMissingDirectory() {
        let result = invoke("vault", "--vault", "/nonexistent/banal-vault")
        XCTAssertEqual(result.code, 1)
        XCTAssertTrue(result.err.contains("no folder at"), result.err)
    }

    // MARK: - notes

    func testNotesJSONListsEveryNoteWithShape() throws {
        let result = invoke("notes", "--vault", vaultURL.path, "--json")
        XCTAssertEqual(result.code, 0)
        let data = try XCTUnwrap(result.out.data(using: .utf8))
        let rows = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertEqual(rows.count, 3)
        let published = try XCTUnwrap(rows.first { ($0["id"] as? String) == "Published Note.md" })
        XCTAssertEqual(published["title"] as? String, "Published Note")
        XCTAssertEqual(published["language"] as? String, "markdown")
        XCTAssertEqual(published["published"] as? Bool, true)
        XCTAssertEqual(published["tags"] as? [String], ["demo"])
        XCTAssertNotNil(published["updated"])
    }

    func testNotesTextModeMarksPublished() {
        let result = invoke("notes", "--vault", vaultURL.path)
        XCTAssertEqual(result.code, 0)
        XCTAssertTrue(result.out.contains("p "), result.out)
        XCTAssertTrue(result.out.contains("Draft.md"), result.out)
    }

    func testNotesPublishedFlagFilters() throws {
        let result = invoke("notes", "--vault", vaultURL.path, "--published", "--json")
        XCTAssertEqual(result.code, 0)
        let data = try XCTUnwrap(result.out.data(using: .utf8))
        let rows = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertTrue(rows.allSatisfy { ($0["published"] as? Bool) == true }, "\(rows)")
        XCTAssertEqual(rows.count, 1)
    }

    // MARK: - show

    func testShowPrintsRawFileBytes() {
        let result = invoke("show", "Published Note.md", "--vault", vaultURL.path)
        XCTAssertEqual(result.code, 0)
        XCTAssertTrue(result.out.contains("published: true"), result.out)
        XCTAssertTrue(result.out.contains("Hello from the CLI."), result.out)
    }

    func testShowJSONParsesTheNote() throws {
        let result = invoke("show", "Published Note.md", "--vault", vaultURL.path, "--json")
        XCTAssertEqual(result.code, 0)
        let data = try XCTUnwrap(result.out.data(using: .utf8))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["title"] as? String, "Published Note")
        XCTAssertTrue((object["body"] as? String)?.contains("Hello from the CLI.") == true)
        XCTAssertFalse((object["body"] as? String)?.contains("published:") == true)
    }

    func testShowRefusesTraversalAndMissingNotes() {
        XCTAssertEqual(invoke("show", "../escape.md", "--vault", vaultURL.path).code, 1)
        XCTAssertEqual(invoke("show", "/etc/passwd", "--vault", vaultURL.path).code, 1)
        XCTAssertEqual(invoke("show", "No Such Note.md", "--vault", vaultURL.path).code, 1)
        XCTAssertTrue(invoke("show", "No Such Note.md", "--vault", vaultURL.path).err.contains("no note"))
    }

    // MARK: - publish

    /// Uses a contract-checking boris stub so the engine choice is identical
    /// on every machine (CI has no boris; some agents do).
    func testPublishRunsTheRealPipeline() throws {
        let stub = try contractStubBoris()
        defer { try? FileManager.default.removeItem(at: stub.deletingLastPathComponent()) }
        var configuration = VaultBootstrap.load(from: vaultURL)
        configuration.borisBinaryPath = stub.path
        try VaultBootstrap.save(configuration)

        let result = invoke("publish", "--vault", vaultURL.path, "--json")
        XCTAssertEqual(result.code, 0, result.err)
        let data = try XCTUnwrap(result.out.data(using: .utf8))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["statusCopy"] as? String, "Published 1 note with Boris.")
        XCTAssertEqual(object["compilerName"] as? String, "boris")
        XCTAssertEqual(object["usedBorisBinary"] as? Bool, true)
        XCTAssertEqual(object["compiledNoteIDs"] as? [String], ["Published Note.md"])

        let index = try XCTUnwrap(object["indexURL"] as? String)
        XCTAssertTrue(FileManager.default.fileExists(atPath: index))
        let artifact = try XCTUnwrap(object["artifactDirectory"] as? String)
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifact + "/Published-Note.html"))
    }

    func testPublishFailsCleanlyWithNothingMarked() throws {
        let empty = FileManager.default.temporaryDirectory
            .appendingPathComponent("banal-cli-empty-\(UUID().uuidString)", isDirectory: true)
        try VaultBootstrap.prepare(VaultConfiguration(rootURL: empty))
        defer { try? FileManager.default.removeItem(at: empty) }
        let result = invoke("publish", "--vault", empty.path)
        XCTAssertEqual(result.code, 1)
        XCTAssertTrue(result.err.contains("Nothing published") || result.err.contains("publish failed"), result.err)
    }

    // MARK: - doctor

    func testDoctorReportsHealthyVault() throws {
        let result = invoke("doctor", "--vault", vaultURL.path, "--json")
        // Absent-but-unconfigured engines warn (exit 64) rather than fail;
        // a machine with both engines gets a clean 0.
        XCTAssertTrue([0, 64].contains(result.code), result.out + result.err)
        let data = try XCTUnwrap(result.out.data(using: .utf8))
        let report = try JSONDecoder().decode(DoctorReport.self, from: data)
        XCTAssertTrue(report.ok)
        XCTAssertEqual(report.checks.first?.name, "vault")
        XCTAssertEqual(report.checks.first?.status, "ok")
        XCTAssertTrue(report.checks.contains { $0.name == "contract" && $0.status == "ok" }, "\(report.checks)")
        for check in report.checks where check.name == "boris" || check.name == "oliver" {
            XCTAssertTrue(["ok", "warn"].contains(check.status), "\(check)")
        }
    }

    func testDoctorFailsWhenConfiguredEngineIsMissing() throws {
        var configuration = VaultBootstrap.load(from: vaultURL)
        configuration.borisBinaryPath = "/nonexistent/boris-binary"
        try VaultBootstrap.save(configuration)

        let result = invoke("doctor", "--vault", vaultURL.path, "--json")
        XCTAssertEqual(result.code, 1)
        let data = try XCTUnwrap(result.out.data(using: .utf8))
        let report = try JSONDecoder().decode(DoctorReport.self, from: data)
        XCTAssertFalse(report.ok)
        let boris = try XCTUnwrap(report.checks.first { $0.name == "boris" })
        XCTAssertEqual(boris.status, "fail")
        XCTAssertTrue(boris.detail.contains("configured"), boris.detail)
    }

    func testDoctorTextModeAlignsRows() {
        let result = invoke("doctor", "--vault", vaultURL.path)
        XCTAssertTrue([0, 64].contains(result.code), result.err)
        XCTAssertTrue(result.out.contains("vault"), result.out)
        XCTAssertTrue(result.out.contains("contract"), result.out)
        let contractRow = result.out.split(separator: "\n").first { $0.hasPrefix("contract") }
        XCTAssertTrue(contractRow?.contains(" ok ") == true, result.out)
    }

    func testDoctorFailsWhenVaultMissing() {
        let result = invoke("doctor", "--vault", "/nonexistent/banal-vault", "--json")
        XCTAssertEqual(result.code, 1)
        XCTAssertTrue(result.err.isEmpty || !result.err.contains("Fatal"), result.err)
    }

    // MARK: - helpers

    /// A stand-in `boris` enforcing the identity contract (#202): whitespace or
    /// `#?%` in the staged content tree exits 3 InvalidPath.
    private func contractStubBoris() throws -> URL {
        let script = """
        #!/bin/sh
        INPUT=content
        OUT=dist
        while [ $# -gt 0 ]; do
          case "$1" in
            --input) INPUT="$2"; shift 2 ;;
            --html-dir) OUT="$2"; shift 2 ;;
            *) shift ;;
          esac
        done
        bad=$(find "$INPUT" -type f | grep -E '[[:space:]#?%]' | head -n 1)
        if [ -n "$bad" ]; then
          echo "error: I/O or system failure: InvalidPath: $bad" >&2
          exit 3
        fi
        mkdir -p "$OUT"
        find "$INPUT" -type f -name '*.md' | while IFS= read -r f; do
          rel="${f#"$INPUT"/}"
          dest="$OUT/${rel%.md}.html"
          mkdir -p "$(dirname "$dest")"
          printf '<html><body>stub</body></html>\\n' > "$dest"
        done
        exit 0
        """
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("banal-cli-stub-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let binary = directory.appendingPathComponent("boris-stub")
        try Data(script.utf8).write(to: binary)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        return binary
    }
}
