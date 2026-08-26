import XCTest
@testable import BANALCore
@testable import BANALPublisher

final class OliverClientTests: XCTestCase {
    func testLocatorAcceptsConfiguredExecutable() {
        let sh = URL(fileURLWithPath: "/bin/sh")
        XCTAssertEqual(OliverLocator.resolve(configured: sh.path), sh)
    }

    func testLocatorPrefersConfiguredOverEnvironment() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let configured = root.appendingPathComponent("configured-oliver")
        let env = root.appendingPathComponent("env-oliver")
        try makeStub(at: configured)
        try makeStub(at: env)
        let found = OliverLocator.resolve(
            configured: configured.path,
            environment: ["BANAL_OLIVER_BIN": env.path, "PATH": ""],
            currentDirectory: root
        )
        XCTAssertEqual(found?.standardizedFileURL, configured.standardizedFileURL)
    }

    func testRecipeJSONResolveHonorsConfiguredPath() throws {
        let binary = OliverLocator.resolveRecipeJSON()
        try XCTSkipUnless(binary != nil, "Oliver binary not on PATH or in a sibling checkout")
        let isolated = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: isolated) }
        let found = OliverLocator.resolveRecipeJSON(
            configured: binary!.path,
            environment: ["PATH": ""],
            currentDirectory: isolated
        )
        XCTAssertEqual(found?.standardizedFileURL, binary!.standardizedFileURL)
    }

    func testLocatorHonorsOliverBinEnvironment() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let stub = root.appendingPathComponent("oliver-stub")
        try makeStub(at: stub)
        let found = OliverLocator.resolve(
            configured: nil,
            environment: ["BANAL_OLIVER_BIN": stub.path, "PATH": ""],
            currentDirectory: root
        )
        XCTAssertEqual(found?.standardizedFileURL, stub.standardizedFileURL)
    }

    func testLocatorFindsSiblingCheckout() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let stub = root.appendingPathComponent("oliver/zig-out/bin/oliver")
        try makeStub(at: stub)
        let cwd = root.appendingPathComponent("banal/worktrees/app", isDirectory: true)
        try FileManager.default.createDirectory(at: cwd, withIntermediateDirectories: true)
        let found = OliverLocator.resolve(
            environment: ["PATH": ""],
            currentDirectory: cwd
        )
        XCTAssertEqual(found?.standardizedFileURL, stub.standardizedFileURL)
    }

    func testLocatorReturnsNilWhenIsolated() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let found = OliverLocator.resolve(
            configured: nil,
            environment: ["PATH": ""],
            currentDirectory: root
        )
        XCTAssertNil(found)
        XCTAssertNil(OliverLocator.resolveRecipeJSON(
            configured: nil,
            environment: ["PATH": ""],
            currentDirectory: root
        ))
    }

    /// A render-only Oliver (no `serialize --json`) is still found for
    /// HTML render, but must not be accepted for recipe Read — Read then
    /// says “This recipe needs Oliver.” instead of “didn’t parse.”
    func testRecipeJSONRejectsBinaryThatCannotSerialize() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let stub = root.appendingPathComponent("oliver")
        try makeStub(at: stub)
        XCTAssertEqual(
            OliverLocator.resolve(
                configured: stub.path,
                environment: ["PATH": ""],
                currentDirectory: root
            )?.standardizedFileURL,
            stub.standardizedFileURL
        )
        XCTAssertNil(OliverLocator.resolveRecipeJSON(
            configured: stub.path,
            environment: ["PATH": ""],
            currentDirectory: root
        ))
    }

    func testLocatorPrefersBundledOverEnvironmentAndPath() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundled = root.appendingPathComponent("bundled-oliver")
        let env = root.appendingPathComponent("env-oliver")
        try makeStub(at: bundled)
        try makeStub(at: env)
        let found = OliverLocator.resolve(
            configured: nil,
            environment: ["BANAL_OLIVER_BIN": env.path, "PATH": "/usr/bin:/bin"],
            currentDirectory: root,
            auxiliaryExecutables: { _ in [bundled] }
        )
        XCTAssertEqual(found?.standardizedFileURL, bundled.standardizedFileURL)
    }

    func testLocatorStillPrefersConfiguredOverBundled() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let configured = root.appendingPathComponent("configured-oliver")
        let bundled = root.appendingPathComponent("bundled-oliver")
        try makeStub(at: configured)
        try makeStub(at: bundled)
        let found = OliverLocator.resolve(
            configured: configured.path,
            environment: ["PATH": ""],
            currentDirectory: root,
            auxiliaryExecutables: { _ in [bundled] }
        )
        XCTAssertEqual(found?.standardizedFileURL, configured.standardizedFileURL)
    }

    /// A bundled helper that is not executable (or absent) must be
    /// skipped — resolution falls through to env/PATH as before.
    func testLocatorSkipsMissingBundledHelper() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let env = root.appendingPathComponent("env-oliver")
        try makeStub(at: env)
        let found = OliverLocator.resolve(
            configured: nil,
            environment: ["BANAL_OLIVER_BIN": env.path, "PATH": ""],
            currentDirectory: root,
            auxiliaryExecutables: { _ in [] }
        )
        XCTAssertEqual(found?.standardizedFileURL, env.standardizedFileURL)
    }

    func testBundledHelperProbesContentsHelpers() {
        let urls = BundledHelper.executables(named: "oliver")
        XCTAssertFalse(urls.isEmpty)
        XCTAssertTrue(
            urls.contains {
                $0.standardizedFileURL.path.hasSuffix("Contents/Helpers/oliver")
            }
        )
    }

    func testLocatorFindsBuiltDistHelper() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let distHelper = root.appendingPathComponent("dist/helpers/oliver")
        try makeStub(at: distHelper)
        let found = OliverLocator.resolve(
            configured: nil,
            environment: ["PATH": ""],
            currentDirectory: root,
            auxiliaryExecutables: { _ in [] }
        )
        XCTAssertEqual(found?.standardizedFileURL, distHelper.standardizedFileURL)
    }

    func testDebounceIsSilentWhenUnavailable() {
        let ask = OliverDebounce(client: nil, delay: 0)
        let exp = expectation(description: "no fire")
        exp.isInverted = true
        ask.schedule(source: "# Hi") { _ in exp.fulfill() }
        wait(for: [exp], timeout: 0.15)
    }

    func testDebounceOnlyRendersTheLastBuffer() {
        let box = SeenBox()
        let ask = OliverDebounce(delay: 0.05) { source in
            box.append(source)
            return OliverRender(html: source)
        }
        let exp = expectation(description: "last buffer")
        ask.schedule(source: "first") { _ in
            XCTFail("first buffer should be cancelled")
        }
        ask.schedule(source: "second") { render in
            box.html = render.html
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(box.items, ["second"])
        XCTAssertEqual(box.html, "second")
    }

    func testMissingBinaryThrows() {
        let url = URL(fileURLWithPath: "/tmp/banal-missing-oliver-\(UUID().uuidString)")
        XCTAssertThrowsError(try OliverClient(binaryURL: url).render("# Hello\n")) { error in
            XCTAssertEqual(error as? OliverError, .missingBinary)
        }
    }

    func testBodyForOliverStripsBANALFrontmatter() {
        let source = """
        ---
        title: Local Title
        created: 2026-08-18T16:00:00Z
        updated: 2026-08-18T16:30:00Z
        published: true
        ---

        # Hello
        """
        let body = OliverClient.bodyForOliver(source)
        XCTAssertTrue(body.contains("# Hello"))
        XCTAssertFalse(body.contains("title: Local Title"))
        XCTAssertFalse(body.hasPrefix("---"))
    }

    func testBodyForOliverLeavesBareMarkdownAlone() {
        let source = "# Just a page\n\nHello.\n"
        XCTAssertEqual(OliverClient.bodyForOliver(source), source)
    }

    func testBodyForOliverDoesNotStripCooklangFences() {
        let source = """
        ---
        servings: 2
        ---

        Boil @pasta{200%g}.
        """
        XCTAssertEqual(OliverClient.bodyForOliver(source, frontend: .cooklang), source)
    }

    func testRendersMarkdownHeadingToHTML() throws {
        let binary = OliverLocator.resolve()
        try XCTSkipUnless(binary != nil, "Oliver binary not on PATH or in a sibling checkout")
        let html = try OliverClient(binaryURL: binary!).render("# Hello\n").html
        XCTAssertTrue(html.contains("<h1>"), "expected a heading tag, got: \(html)")
        XCTAssertTrue(html.contains("Hello"), "expected heading text, got: \(html)")
    }

    func testRenderStripsFrontmatterSoOliverDoesNotSeeLocalKeys() throws {
        let binary = OliverLocator.resolve()
        try XCTSkipUnless(binary != nil, "Oliver binary not on PATH or in a sibling checkout")
        let source = """
        ---
        title: Local Title
        created: 2026-08-18T16:00:00Z
        updated: 2026-08-18T16:30:00Z
        published: true
        ---

        # Hello
        """
        let html = try OliverClient(binaryURL: binary!).render(source).html
        XCTAssertTrue(html.contains("<h1>"), "expected a heading tag, got: \(html)")
        XCTAssertTrue(html.contains("Hello"), "expected heading text, got: \(html)")
        XCTAssertFalse(html.contains("Local Title"), "Oliver must not render BANAL frontmatter: \(html)")
        XCTAssertFalse(html.lowercased().contains("<hr"), "fences must not become a thematic break: \(html)")
    }
}

private func isolatedRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("banal-oliver-\(UUID().uuidString)", isDirectory: true)
}

private func makeStub(at url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("#!/bin/sh\n".utf8).write(to: url, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
}

/// Records render calls from the debounce test seam.
private final class SeenBox: @unchecked Sendable {
    private let lock = NSLock()
    private var seen: [String] = []
    var html: String?

    var items: [String] {
        lock.lock()
        defer { lock.unlock() }
        return seen
    }

    func append(_ value: String) {
        lock.lock()
        seen.append(value)
        lock.unlock()
    }
}
