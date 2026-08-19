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

    func testEntityIDDropsLanguageExtensionUnlessClash() {
        let now = Date()
        let essay = Note(
            id: "hello.md",
            fileURL: URL(fileURLWithPath: "/tmp/hello.md"),
            title: "Hello",
            body: "Hi",
            created: now,
            updated: now,
            published: true,
            modifiedAt: now
        )
        let recipe = Note(
            id: "hello.cook",
            fileURL: URL(fileURLWithPath: "/tmp/hello.cook"),
            title: "Hello",
            body: "Add @salt{}.",
            created: now,
            updated: now,
            published: true,
            modifiedAt: now
        )
        XCTAssertEqual(BorisAdapter.entityID(for: essay), "hello")
        XCTAssertEqual(BorisAdapter.entityID(for: essay, among: [essay, recipe]), "hello.md")
        XCTAssertEqual(BorisAdapter.entityID(for: recipe, among: [essay, recipe]), "hello.cook")
        XCTAssertEqual(BorisAdapter.sourceRelativePath(for: essay, entityID: "hello"), "hello.md")
        XCTAssertEqual(BorisAdapter.sourceRelativePath(for: recipe, entityID: "hello"), "hello.cook")
    }

    func testCookStagesAsCooklangNotYAML() {
        let now = Date()
        let recipe = Note(
            id: "Recipes/risotto.cook",
            fileURL: URL(fileURLWithPath: "/tmp/Recipes/risotto.cook"),
            title: "Risotto",
            body: "Add @arborio rice{300%g}.\n",
            created: now,
            updated: now,
            published: true,
            modifiedAt: now
        )
        let source = BorisAdapter.serializeBorisSource(note: recipe, entityID: "Recipes/risotto")
        XCTAssertTrue(source.contains(">> title: Risotto"))
        XCTAssertTrue(source.contains(">> published: true"))
        XCTAssertFalse(source.contains("---"))
        XCTAssertFalse(source.contains("status: published"))
        XCTAssertTrue(source.contains("@arborio rice{300%g}"))
        let page = BorisAdapter.page(from: recipe, among: [recipe])
        XCTAssertEqual(page.relativePath, "Recipes/risotto.cook")
        XCTAssertEqual(page.language, .cooklang)
    }

    func testBuiltinSkipsCookWithoutOliver() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-skip-cook-\(UUID().uuidString)", isDirectory: true)
        let vault = VaultConfiguration(rootURL: root, siteTitle: "Field Notes")
        try VaultBootstrap.prepare(vault)
        defer { try? FileManager.default.removeItem(at: root) }

        let now = Date()
        let essay = Note(
            id: "alpha.md",
            fileURL: root.appendingPathComponent("alpha.md"),
            title: "Alpha",
            body: "\nHello.\n",
            created: now,
            updated: now,
            published: true,
            modifiedAt: now
        )
        let recipe = Note(
            id: "Recipes/risotto.cook",
            fileURL: root.appendingPathComponent("Recipes/risotto.cook"),
            title: "Risotto",
            body: "Add @arborio rice{300%g}.\n",
            created: now,
            updated: now,
            published: true,
            modifiedAt: now
        )
        try FileManager.default.createDirectory(at: recipe.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = ">> title: Risotto\n\nAdd @arborio rice{300%g}.\n"
        try Data(original.utf8).write(to: recipe.fileURL)

        let configuration = PublishConfiguration(
            siteTitle: "Field Notes",
            artifactDirectory: root.appendingPathComponent(".publish"),
            stagingDirectory: root.appendingPathComponent(".banal/stage"),
            preferBoris: false
        )
        let result = try BANALPublisher(compiler: BuiltinSiteCompiler(), oliver: nil).publish(
            notes: [essay, recipe],
            vault: vault,
            configuration: configuration,
            now: now
        )
        XCTAssertEqual(result.compiledNoteIDs, ["alpha.md"])
        XCTAssertEqual(result.skipped.map(\.noteID), ["Recipes/risotto.cook"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.artifactDirectory.appendingPathComponent("alpha.html").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.artifactDirectory.appendingPathComponent("Recipes/risotto.html").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: configuration.stagingDirectory.appendingPathComponent("content/Recipes/risotto.cook").path))
        XCTAssertEqual(try String(contentsOf: recipe.fileURL, encoding: .utf8), original)
    }

    func testCookOnlyWithoutOliverFailsInOneSentence() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-only-cook-\(UUID().uuidString)", isDirectory: true)
        let vault = VaultConfiguration(rootURL: root)
        let now = Date()
        let recipe = Note(
            id: "risotto.cook",
            fileURL: root.appendingPathComponent("risotto.cook"),
            title: "Risotto",
            body: "Add @salt{}.\n",
            created: now,
            updated: now,
            published: true,
            modifiedAt: now
        )
        let configuration = PublishConfiguration(
            artifactDirectory: root.appendingPathComponent(".publish"),
            stagingDirectory: root.appendingPathComponent(".banal/stage"),
            preferBoris: false
        )
        XCTAssertThrowsError(
            try BANALPublisher(compiler: BuiltinSiteCompiler(), oliver: nil).publish(
                notes: [recipe],
                vault: vault,
                configuration: configuration
            )
        ) { error in
            XCTAssertEqual(error as? PublishError, .nothingCompiled)
        }
    }

    func testMixedPublishWritesCookHTMLWhenOliverPresent() throws {
        let binary = OliverLocator.resolve()
        try XCTSkipUnless(binary != nil, "Oliver binary not on PATH or in a sibling checkout")
        let client = OliverClient(binaryURL: binary!)

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-mixed-\(UUID().uuidString)", isDirectory: true)
        let vault = VaultConfiguration(rootURL: root, siteTitle: "Field Notes")
        try VaultBootstrap.prepare(vault)
        defer { try? FileManager.default.removeItem(at: root) }

        let now = Date()
        let one = Note(
            id: "alpha.md",
            fileURL: root.appendingPathComponent("alpha.md"),
            title: "Alpha",
            body: "\n# Alpha\n\nHello.\n",
            created: now,
            updated: now,
            published: true,
            modifiedAt: now
        )
        let two = Note(
            id: "beta.md",
            fileURL: root.appendingPathComponent("beta.md"),
            title: "Beta",
            body: "\n# Beta\n\nThere.\n",
            created: now,
            updated: now,
            published: true,
            modifiedAt: now
        )
        let recipe = Note(
            id: "Recipes/risotto.cook",
            fileURL: root.appendingPathComponent("Recipes/risotto.cook"),
            title: "Risotto",
            body: "Add @arborio rice{300%g} to the pan.\n",
            created: now,
            updated: now,
            published: true,
            modifiedAt: now
        )
        try FileManager.default.createDirectory(at: recipe.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = ">> title: Risotto\n\nAdd @arborio rice{300%g} to the pan.\n"
        try Data(original.utf8).write(to: recipe.fileURL)

        let configuration = PublishConfiguration(
            siteTitle: "Field Notes",
            artifactDirectory: root.appendingPathComponent(".publish"),
            stagingDirectory: root.appendingPathComponent(".banal/stage"),
            preferBoris: false
        )
        let result = try BANALPublisher(compiler: BuiltinSiteCompiler(), oliver: client).publish(
            notes: [one, two, recipe],
            vault: vault,
            configuration: configuration,
            now: now
        )
        XCTAssertEqual(Set(result.compiledNoteIDs), ["alpha.md", "beta.md", "Recipes/risotto.cook"])
        XCTAssertTrue(result.skipped.isEmpty)
        let risotto = try String(contentsOf: result.artifactDirectory.appendingPathComponent("Recipes/risotto.html"), encoding: .utf8)
        XCTAssertTrue(risotto.contains("arborio") || risotto.contains("ingredient"), risotto)
        let index = try String(contentsOf: result.indexURL, encoding: .utf8)
        XCTAssertTrue(index.contains("Recipes/risotto.html") || index.contains("risotto"))
        XCTAssertEqual(try String(contentsOf: recipe.fileURL, encoding: .utf8), original)
    }

    func testDeployRequiresTokenAndProject() {
        XCTAssertFalse(CloudflareDeployer.canDeploy(projectName: "", token: "tok"))
        XCTAssertFalse(CloudflareDeployer.canDeploy(projectName: "notes", token: nil))
        XCTAssertFalse(CloudflareDeployer.canDeploy(projectName: "notes", token: "  "))
        XCTAssertTrue(CloudflareDeployer.canDeploy(projectName: "notes", token: "tok"))
    }

    func testDeployRunnerSeesTokenAndRedactsIt() throws {
        let plan = CloudflareDeployer.plan(
            artifactDirectory: URL(fileURLWithPath: "/tmp/out"),
            projectName: "banal-notes",
            accountID: "abc",
            dryRun: false
        )
        let log = try CloudflareDeployer.deploy(plan: plan, token: "secret-token") { received, environment in
            XCTAssertEqual(environment["CLOUDFLARE_API_TOKEN"], "secret-token")
            XCTAssertEqual(received.projectName, "banal-notes")
            return "ok secret-token done"
        }
        XCTAssertEqual(log, "ok *** done")
        XCTAssertThrowsError(try CloudflareDeployer.deploy(plan: plan, token: "")) { error in
            XCTAssertEqual(error as? CloudflareDeployError, .notConnected)
        }
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
