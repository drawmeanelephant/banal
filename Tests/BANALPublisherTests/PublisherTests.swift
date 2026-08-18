import XCTest
@testable import BANALCore
@testable import BANALPublisher

final class PublisherTests: XCTestCase {
    func testBorisMappingStripsLocalOnlyKeys() {
        let now = DateFormatting.date(from: "2026-08-18T12:00:00Z")!
        let note = Note(
            id: "essays/hello",
            fileURL: URL(fileURLWithPath: "/tmp/essays/hello.md"),
            title: "Hello",
            body: "\nHi from BANAL.\n",
            created: now,
            updated: now,
            tags: ["essays"],
            published: true,
            modifiedAt: now
        )
        let source = BorisAdapter.serializeBorisSource(note: note, entityID: "essays/hello")
        XCTAssertTrue(source.contains("id: essays/hello"))
        XCTAssertTrue(source.contains("status: published"))
        XCTAssertTrue(source.contains("tags: [essays]"))
        XCTAssertFalse(source.contains("published:"))
        XCTAssertFalse(source.contains("created:"))
        XCTAssertFalse(source.contains("updated:"))
        XCTAssertTrue(source.contains("Hi from BANAL."))
    }

    func testBuiltinPublishWritesHTMLIndexAndRSS() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-pub-\(UUID().uuidString)", isDirectory: true)
        let vault = VaultConfiguration(rootURL: root, siteTitle: "Field Notes")
        try VaultBootstrap.prepare(vault)
        defer { try? FileManager.default.removeItem(at: root) }

        let now = DateFormatting.date(from: "2026-08-18T12:00:00Z")!
        let published = Note(
            id: "alpha",
            fileURL: root.appendingPathComponent("alpha.md"),
            title: "Alpha",
            body: "\n# Alpha\n\nHello **world**.\n",
            created: now,
            updated: now,
            tags: ["letters"],
            published: true,
            modifiedAt: now
        )
        let draft = Note(
            id: "secret",
            fileURL: root.appendingPathComponent("secret.md"),
            title: "Secret",
            body: "\nShould not publish.\n",
            created: now,
            updated: now,
            published: false,
            modifiedAt: now
        )

        let configuration = PublishConfiguration(
            siteTitle: "Field Notes",
            siteBaseURL: "https://notes.example",
            artifactDirectory: root.appendingPathComponent(".publish"),
            stagingDirectory: root.appendingPathComponent(".banal/stage"),
            preferBoris: false
        )
        let result = try BANALPublisher(compiler: BuiltinSiteCompiler()).publish(
            notes: [published, draft],
            vault: vault,
            configuration: configuration,
            now: now
        )

        XCTAssertFalse(result.usedBorisBinary)
        XCTAssertEqual(result.compilerName, "builtin")
        XCTAssertEqual(result.compiledNoteIDs, ["alpha"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.indexURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.rssURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.artifactDirectory.appendingPathComponent("alpha.html").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.artifactDirectory.appendingPathComponent("secret.html").path))

        let index = try String(contentsOf: result.indexURL, encoding: .utf8)
        XCTAssertTrue(index.contains("Field Notes"))
        XCTAssertTrue(index.contains("alpha.html"))

        let page = try String(contentsOf: result.artifactDirectory.appendingPathComponent("alpha.html"), encoding: .utf8)
        XCTAssertTrue(page.contains("<strong>world</strong>"))

        let rss = try String(contentsOf: result.rssURL, encoding: .utf8)
        XCTAssertTrue(rss.contains("<title>Alpha</title>"))
        XCTAssertTrue(rss.contains("https://notes.example/alpha.html"))

        let staged = try String(contentsOf: configuration.stagingDirectory.appendingPathComponent("content/alpha.md"), encoding: .utf8)
        XCTAssertTrue(staged.contains("status: published"))
        XCTAssertFalse(staged.contains("created:"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.artifactDirectory.appendingPathComponent("wrangler.toml").path))
    }

    func testPublishWithoutPublishedNotesFails() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-empty-\(UUID().uuidString)", isDirectory: true)
        let vault = VaultConfiguration(rootURL: root)
        let configuration = PublishConfiguration(
            artifactDirectory: root.appendingPathComponent("out"),
            stagingDirectory: root.appendingPathComponent("stage"),
            preferBoris: false
        )
        XCTAssertThrowsError(
            try BANALPublisher(compiler: BuiltinSiteCompiler()).publish(notes: [], vault: vault, configuration: configuration)
        ) { error in
            XCTAssertEqual(error as? PublishError, .noPublishedNotes)
        }
    }

    func testBorisCLICompileWhenBinaryPresent() throws {
        let binary = BorisLocator.resolve(configured: nil)
        try XCTSkipUnless(binary != nil, "Boris binary not on PATH or in a sibling checkout")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-boris-\(UUID().uuidString)", isDirectory: true)
        let vault = VaultConfiguration(rootURL: root, siteTitle: "Boris Notes", borisBinaryPath: binary?.path)
        try VaultBootstrap.prepare(vault)
        defer { try? FileManager.default.removeItem(at: root) }

        let now = Date()
        let note = Note(
            id: "from-boris",
            fileURL: root.appendingPathComponent("from-boris.md"),
            title: "From Boris",
            body: "\nCompiled by the real engine.\n",
            created: now,
            updated: now,
            published: true,
            modifiedAt: now
        )
        let configuration = PublishConfiguration(
            siteTitle: "Boris Notes",
            artifactDirectory: root.appendingPathComponent(".publish"),
            stagingDirectory: root.appendingPathComponent(".banal/stage"),
            borisBinaryURL: binary,
            preferBoris: true
        )
        let result = try BANALPublisher.make(configuration: configuration).publish(
            notes: [note],
            vault: vault,
            configuration: configuration
        )
        XCTAssertTrue(result.usedBorisBinary)
        XCTAssertEqual(result.compilerName, "boris")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.indexURL.path))
        let html = try String(contentsOf: result.artifactDirectory.appendingPathComponent("from-boris.html"), encoding: .utf8)
        XCTAssertTrue(html.contains("Compiled by the real engine") || html.contains("<main>"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.rssURL.path))
    }

    func testCloudflarePlanIsDryRun() {
        let plan = CloudflareDeployer.plan(
            artifactDirectory: URL(fileURLWithPath: "/tmp/out"),
            projectName: "banal-notes",
            accountID: "abc123",
            dryRun: true
        )
        XCTAssertTrue(plan.dryRun)
        XCTAssertEqual(Array(plan.command.prefix(4)), ["npx", "wrangler", "pages", "deploy"])
        XCTAssertTrue(plan.wranglerTOML.contains("name = \"banal-notes\""))
        XCTAssertTrue(plan.wranglerTOML.contains("abc123"))
    }
}
