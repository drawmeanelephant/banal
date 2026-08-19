import XCTest
@testable import BANALCore

final class VaultBookmarkTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "dev.drawmeanelephant.banal.tests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        VaultBookmark.endAccess()
        SecurityScope.stopAll()
        if !suiteName.isEmpty {
            defaults?.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
    }

    func testRestoreWithoutBookmarkIsNil() {
        XCTAssertNil(VaultBookmark.restore(defaults: defaults, environment: [:]))
        XCTAssertEqual(
            NotesFolderAccess.resolveRemembered(defaults: defaults, environment: [:]),
            .firstRun
        )
    }

    func testSaveAndRestoreRoundTripsURL() throws {
        let url = try makeFolder()
        defer { try? FileManager.default.removeItem(at: url) }

        VaultBookmark.save(url, defaults: defaults, environment: [:])
        XCTAssertNotNil(defaults.data(forKey: VaultBookmark.bookmarkKey))
        XCTAssertEqual(defaults.string(forKey: VaultBookmark.pathKey), url.path)

        VaultBookmark.endAccess()
        let restored = try XCTUnwrap(VaultBookmark.restore(defaults: defaults, environment: [:]))
        XCTAssertEqual(normalized(restored), normalized(url))
        let access = NotesFolderAccess.resolveRemembered(defaults: defaults, environment: [:])
        guard case .ready(let ready) = access else {
            return XCTFail("expected ready, got \(access)")
        }
        XCTAssertEqual(normalized(ready), normalized(url))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testVanishedFolderRestoreKeepsPathAndDoesNotCreate() throws {
        let url = try makeFolder()
        VaultBookmark.save(url, defaults: defaults, environment: [:])
        try FileManager.default.removeItem(at: url)

        VaultBookmark.endAccess()
        let restored = try XCTUnwrap(VaultBookmark.restore(defaults: defaults, environment: [:]))
        let access = NotesFolderAccess.resolve(remembered: restored)

        guard case .missing(let remembered) = access else {
            return XCTFail("expected missing, got \(access)")
        }
        XCTAssertEqual(normalized(remembered), normalized(url))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testResolveDoesNotCreateMissingDirectory() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "banal-missing-\(UUID().uuidString)",
            isDirectory: true
        )
        XCTAssertEqual(NotesFolderAccess.resolve(remembered: url), .missing(url))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testOverrideDoesNotWriteBookmark() throws {
        let url = try makeFolder()
        defer { try? FileManager.default.removeItem(at: url) }
        let env = ["BANAL_VAULT": url.path]
        let other = FileManager.default.temporaryDirectory.appendingPathComponent(
            "banal-other-\(UUID().uuidString)",
            isDirectory: true
        )

        VaultBookmark.save(other, defaults: defaults, environment: env)
        XCTAssertNil(defaults.data(forKey: VaultBookmark.bookmarkKey))
        XCTAssertNil(defaults.string(forKey: VaultBookmark.pathKey))

        let restored = try XCTUnwrap(VaultBookmark.restore(defaults: defaults, environment: env))
        XCTAssertEqual(normalized(restored), normalized(url))
    }

    func testDefaultVaultURLIsDocumentsBANALNotes() {
        let url = VaultBookmark.defaultVaultURL()
        XCTAssertTrue(url.path.hasSuffix("Documents/BANAL Notes"))
        XCTAssertFalse(url.path.contains("/Containers/"))
    }

    func testCreateFolderIfAllowedThenEndAccessLeavesFolder() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "banal-allowed-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: url) }
        let created = try XCTUnwrap(VaultBookmark.createFolderIfAllowed(url))
        XCTAssertEqual(normalized(created), normalized(url))
        VaultBookmark.endAccess()
        SecurityScope.stopAll()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testRestoredFolderStillAcceptsPublishDirectory() throws {
        let url = try makeFolder()
        defer { try? FileManager.default.removeItem(at: url) }
        VaultBookmark.save(url, defaults: defaults, environment: [:])
        VaultBookmark.endAccess()

        let restored = try XCTUnwrap(VaultBookmark.restore(defaults: defaults, environment: [:]))
        let publish = restored.appendingPathComponent(".publish", isDirectory: true)
        try FileManager.default.createDirectory(at: publish, withIntermediateDirectories: true)
        let index = publish.appendingPathComponent("index.html")
        try Data("<html></html>".utf8).write(to: index, options: .atomic)
        XCTAssertTrue(FileManager.default.fileExists(atPath: index.path))

        try FileManager.default.removeItem(at: url)
        VaultBookmark.endAccess()
        let after = NotesFolderAccess.resolveRemembered(defaults: defaults, environment: [:])
        guard case .missing = after else {
            return XCTFail("expected missing after vanish, got \(after)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: publish.path))
    }

    func testCompilerBookmarkForgetClearsData() throws {
        let url = try makeFolder().appendingPathComponent("oliver")
        try Data("#!/bin/sh\n".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        CompilerBookmark.save(url, name: "oliver", defaults: defaults)
        XCTAssertNotNil(defaults.data(forKey: CompilerBookmark.defaultsKey("oliver")))
        CompilerBookmark.forget(name: "oliver", defaults: defaults)
        XCTAssertNil(defaults.data(forKey: CompilerBookmark.defaultsKey("oliver")))
    }

    private func makeFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "banal-bookmark-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func normalized(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
