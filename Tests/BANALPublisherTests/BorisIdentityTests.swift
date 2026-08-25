import XCTest
@testable import BANALCore
@testable import BANALPublisher

/// The Boris identity boundary (#202): plain names on disk, Boris-valid ids in
/// the publish pipeline.
final class BorisIdentityTests: XCTestCase {
    private let now = Date()

    private func note(id: String, title: String, published: Bool = true) -> Note {
        Note(
            id: id,
            fileURL: URL(fileURLWithPath: "/tmp/vault/\(id)"),
            title: title,
            body: "\nBody of \(title).\n",
            created: now,
            updated: now,
            published: published,
            modifiedAt: now
        )
    }

    // MARK: - Contract validation

    func testValidatorMirrorsBorisContract() {
        XCTAssertTrue(BorisIdentity.isValid("hello"))
        XCTAssertTrue(BorisIdentity.isValid("Recipes/Tom Kha".replacingOccurrences(of: " ", with: "-")))
        XCTAssertTrue(BorisIdentity.isValid("café-viennois"))
        XCTAssertTrue(BorisIdentity.isValid(String(repeating: "a", count: 255)))
        XCTAssertTrue(BorisIdentity.isValid(String(repeating: "€", count: 85))) // 85 × 3 bytes = 255
        XCTAssertFalse(BorisIdentity.isValid(""))
        XCTAssertFalse(BorisIdentity.isValid("Tom Kha"))
        XCTAssertFalse(BorisIdentity.isValid("tab\tid"))
        XCTAssertFalse(BorisIdentity.isValid("line\nbreak"))
        XCTAssertFalse(BorisIdentity.isValid("c#-notes"))
        XCTAssertFalse(BorisIdentity.isValid("what?"))
        XCTAssertFalse(BorisIdentity.isValid("100%"))
        XCTAssertFalse(BorisIdentity.isValid("back\\slash"))
        XCTAssertFalse(BorisIdentity.isValid(String(repeating: "x", count: 256)))
        XCTAssertFalse(BorisIdentity.isValid(String(repeating: "€", count: 86))) // 258 bytes
        for segment in [".", "..", "", "a//b", "a/./b", "a/../b"] {
            let id = segment.isEmpty ? "/" : (segment.contains("/") ? segment : "a/\(segment)")
            XCTAssertFalse(BorisIdentity.isValid(id), "expected rejection: \(id)")
        }
    }

    // MARK: - Sanitization

    func testSanitizeReplacesWhitespaceAndURLSignificantRuns() {
        XCTAssertEqual(BorisIdentity.sanitizedEntityID(from: "Published Note"), "Published-Note")
        XCTAssertEqual(BorisIdentity.sanitizedEntityID(from: "Tom   Kha"), "Tom-Kha")
        XCTAssertEqual(BorisIdentity.sanitizedEntityID(from: "line\nbreak"), "line-break")
        XCTAssertEqual(BorisIdentity.sanitizedEntityID(from: "C# Notes"), "C-Notes")
        XCTAssertEqual(BorisIdentity.sanitizedEntityID(from: "What? Why?"), "What-Why")
        XCTAssertEqual(BorisIdentity.sanitizedEntityID(from: "50% Off"), "50-Off")
        XCTAssertEqual(BorisIdentity.sanitizedEntityID(from: "back\\slash"), "back-slash")
    }

    func testSanitizeKeepsCaseAccentsFoldersAndDots() {
        XCTAssertEqual(BorisIdentity.sanitizedEntityID(from: "Café Viennois"), "Café-Viennois")
        XCTAssertEqual(BorisIdentity.sanitizedEntityID(from: "Recipes/Tom Kha"), "Recipes/Tom-Kha")
        XCTAssertEqual(BorisIdentity.sanitizedEntityID(from: "R2-D2 v1.2 notes"), "R2-D2-v1.2-notes")
        XCTAssertEqual(BorisIdentity.sanitizedEntityID(from: " - edged - "), "edged")
    }

    func testSanitizeFallsBackToUntitledWhenNothingSurvives() {
        XCTAssertEqual(BorisIdentity.sanitizedEntityID(from: ""), "untitled")
        XCTAssertEqual(BorisIdentity.sanitizedEntityID(from: "?## %"), "untitled")
        XCTAssertEqual(BorisIdentity.sanitizedEntityID(from: "..."), "untitled")
    }

    // MARK: - Entity assignment

    func testSpacedPlainNameStagesToBorisValidEntity() {
        let spaced = note(id: "Published Note.md", title: "Published Note")
        XCTAssertEqual(BorisAdapter.entityID(for: spaced), "Published-Note")
        let page = BorisAdapter.page(from: spaced)
        XCTAssertTrue(BorisIdentity.isValid(page.entityID))
        XCTAssertEqual(page.relativePath, "Published-Note.md")
    }

    func testAssignmentIsUniqueAcrossWholeSet() {
        let notes = [
            note(id: "A B.md", title: "A B"),
            note(id: "A-B.md", title: "A-B"),
            note(id: "Hello World.cook", title: "Hello World"),
            note(id: "Essays/My Note.md", title: "My Note"),
        ]
        let assigned = BorisAdapter.entityIDs(for: notes)
        XCTAssertEqual(Set(assigned.values).count, assigned.count, "\(assigned)")
        for entity in assigned.values {
            XCTAssertTrue(BorisIdentity.isValid(entity), entity)
        }
        // Markdown claims the bare stem; any other claimant takes Finder-style
        // numbering — ids never carry file extensions.
        XCTAssertEqual(assigned["A B.md"], "A-B")
        XCTAssertEqual(assigned["A-B.md"], "A-B-2")
        XCTAssertEqual(assigned["Hello World.cook"], "Hello-World")
        XCTAssertEqual(assigned["Essays/My Note.md"], "Essays/My-Note")

        // Staged paths therefore never double up extensions.
        let cook = notes.first { $0.id == "Hello World.cook" }!
        XCTAssertEqual(
            BorisAdapter.sourceRelativePath(for: cook, entityID: assigned[cook.id]!),
            "Hello-World.cook"
        )
    }

    func testAssignmentIsOrderIndependent() {
        let one = note(id: "A B.md", title: "A B")
        let two = note(id: "A-B.md", title: "A-B")
        XCTAssertEqual(BorisAdapter.entityIDs(for: [one, two]), BorisAdapter.entityIDs(for: [two, one]))
    }

    func testCrossLanguageClashStillSplitsByFilename() {
        let essay = note(id: "hello.md", title: "Hello")
        let recipe = note(id: "hello.cook", title: "Hello")
        XCTAssertEqual(BorisAdapter.entityIDs(for: [essay, recipe])["hello.md"], "hello")
        XCTAssertEqual(BorisAdapter.entityIDs(for: [essay, recipe])["hello.cook"], "hello-2")
    }

    func testNumberingBreaksResidualTies() {
        // Three notes that all sanitize into the same family.
        let notes = [
            note(id: "Q?.md", title: "Q"),
            note(id: "Q .md", title: "Q"),
            note(id: "Q#.md", title: "Q"),
        ]
        let assigned = BorisAdapter.entityIDs(for: notes)
        XCTAssertEqual(Set(assigned.values).count, 3, "\(assigned)")
        for entity in assigned.values {
            XCTAssertTrue(BorisIdentity.isValid(entity), entity)
        }
        XCTAssertTrue(assigned.values.contains("Q"), "\(assigned)")
        XCTAssertTrue(assigned.values.contains("Q-2"), "\(assigned)")
        XCTAssertTrue(assigned.values.contains("Q-3"), "\(assigned)")
    }

    // MARK: - Staging end to end (builtin compiler)

    func testStageWritesOnlyBorisValidPathsForSpacedTitles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-spaced-\(UUID().uuidString)", isDirectory: true)
        let vault = VaultConfiguration(rootURL: root, siteTitle: "Field Notes")
        try VaultBootstrap.prepare(vault)
        defer { try? FileManager.default.removeItem(at: root) }

        let configuration = PublishConfiguration(
            siteTitle: "Field Notes",
            artifactDirectory: root.appendingPathComponent(".publish"),
            stagingDirectory: root.appendingPathComponent(".banal/stage"),
            preferBoris: false
        )
        let result = try BANALPublisher(compiler: BuiltinSiteCompiler()).publish(
            notes: [
                note(id: "Published Note.md", title: "Published Note"),
                note(id: "Recipes/Tom Kha.cook", title: "Tom Kha"),
            ],
            vault: vault,
            configuration: configuration
        )

        let fileManager = FileManager.default
        let stageRoot = configuration.stagingDirectory.resolvingSymlinksInPath().path
        var stagedPaths: [String] = []
        let enumerator = fileManager.enumerator(at: configuration.stagingDirectory, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            let relative = String(url.resolvingSymlinksInPath().path.dropFirst(stageRoot.count + 1))
            stagedPaths.append(relative)
        }
        for relative in stagedPaths {
            if relative.hasPrefix("dist/") || relative == "dist" { continue }
            XCTAssertTrue(BorisIdentity.isValid(relative), "staged path violates contract: \(relative)")
        }
        XCTAssertTrue(stagedPaths.contains("content/Published-Note.md"), "\(stagedPaths)")
        XCTAssertFalse(stagedPaths.contains("content/Published Note.md"))

        let staged = try String(contentsOf: configuration.stagingDirectory.appendingPathComponent("content/Published-Note.md"), encoding: .utf8)
        XCTAssertTrue(staged.contains("id: Published-Note"))
        XCTAssertTrue(fileManager.fileExists(atPath: result.artifactDirectory.appendingPathComponent("Published-Note.html").path))
    }

    /// A stand-in compiler that enforces the same rule real boris does
    /// (`src/identity.zig`): any whitespace or `#?%` in the content tree exits 3
    /// with InvalidPath. Runs everywhere, so CI catches staging regressions
    /// even without boris installed.
    func testContractCheckingCompilerAcceptsSanitizedStaging() throws {
        let stub = """
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
          printf '<html><body>stub</body></html>\n' > "$dest"
        done
        exit 0
        """

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-stub-boris-\(UUID().uuidString)", isDirectory: true)
        let vault = VaultConfiguration(rootURL: root, siteTitle: "Field Notes")
        try VaultBootstrap.prepare(vault)
        defer { try? FileManager.default.removeItem(at: root) }

        let binary = root.appendingPathComponent("boris-stub")
        try Data(stub.utf8).write(to: binary)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)

        let configuration = PublishConfiguration(
            siteTitle: "Field Notes",
            artifactDirectory: root.appendingPathComponent(".publish"),
            stagingDirectory: root.appendingPathComponent(".banal/stage"),
            borisBinaryURL: binary,
            preferBoris: true
        )
        let result = try BANALPublisher.make(configuration: configuration).publish(
            notes: [note(id: "From Boris.md", title: "From Boris")],
            vault: vault,
            configuration: configuration
        )
        XCTAssertTrue(result.usedBorisBinary)
        XCTAssertEqual(result.compilerName, "boris")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.artifactDirectory.appendingPathComponent("From-Boris.html").path))
    }

    /// The exact repro from #202 against the real engine. Skips where boris is
    /// absent (CI); fails on any machine that has it, before the fix.
    func testSpacedTitlePublishesThroughRealBoris() throws {
        let binary = BorisLocator.resolve(configured: nil)
        try XCTSkipUnless(binary != nil, "Boris binary not on PATH or in a sibling checkout")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-boris-spaced-\(UUID().uuidString)", isDirectory: true)
        let vault = VaultConfiguration(rootURL: root, siteTitle: "Field Notes")
        try VaultBootstrap.prepare(vault)
        defer { try? FileManager.default.removeItem(at: root) }

        let configuration = PublishConfiguration(
            siteTitle: "Field Notes",
            artifactDirectory: root.appendingPathComponent(".publish"),
            stagingDirectory: root.appendingPathComponent(".banal/stage"),
            borisBinaryURL: binary,
            preferBoris: true
        )
        let result = try BANALPublisher.make(configuration: configuration).publish(
            notes: [note(id: "Published Note.md", title: "Published Note")],
            vault: vault,
            configuration: configuration
        )
        XCTAssertTrue(result.usedBorisBinary)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.indexURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.artifactDirectory.appendingPathComponent("Published-Note.html").path))
    }
}
