import XCTest
@testable import BANALCore
@testable import BANALPublisher

final class BorisLocatorTests: XCTestCase {
    func testLocatorPrefersBundledOverEnvironmentAndPath() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundled = root.appendingPathComponent("bundled-boris")
        let env = root.appendingPathComponent("env-boris")
        try makeStub(at: bundled)
        try makeStub(at: env)
        let found = BorisLocator.resolve(
            configured: nil,
            environment: ["BANAL_BORIS_BIN": env.path, "PATH": "/usr/bin:/bin"],
            auxiliaryExecutables: { _ in [bundled] }
        )
        XCTAssertEqual(found?.standardizedFileURL, bundled.standardizedFileURL)
    }

    func testLocatorStillPrefersConfiguredOverBundled() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let configured = root.appendingPathComponent("configured-boris")
        let bundled = root.appendingPathComponent("bundled-boris")
        try makeStub(at: configured)
        try makeStub(at: bundled)
        let found = BorisLocator.resolve(
            configured: configured.path,
            environment: ["PATH": ""],
            auxiliaryExecutables: { _ in [bundled] }
        )
        XCTAssertEqual(found?.standardizedFileURL, configured.standardizedFileURL)
    }

    func testLocatorReturnsNilWhenIsolated() {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertNil(BorisLocator.resolve(
            configured: nil,
            environment: ["PATH": ""],
            currentDirectory: root,
            auxiliaryExecutables: { _ in [] }
        ))
    }

    func testLocatorHonorsBorisBinEnvironment() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let stub = root.appendingPathComponent("boris-stub")
        try makeStub(at: stub)
        let found = BorisLocator.resolve(
            configured: nil,
            environment: ["BANAL_BORIS_BIN": stub.path, "PATH": ""],
            currentDirectory: root,
            auxiliaryExecutables: { _ in [] }
        )
        XCTAssertEqual(found?.standardizedFileURL, stub.standardizedFileURL)
    }

    func testLocatorFindsBuiltDistHelper() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let distHelper = root.appendingPathComponent("dist/helpers/boris")
        try makeStub(at: distHelper)
        let found = BorisLocator.resolve(
            configured: nil,
            environment: ["PATH": ""],
            currentDirectory: root,
            auxiliaryExecutables: { _ in [] }
        )
        XCTAssertEqual(found?.standardizedFileURL, distHelper.standardizedFileURL)
    }
}

private func isolatedRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("banal-boris-\(UUID().uuidString)", isDirectory: true)
}

private func makeStub(at url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("#!/bin/sh\n".utf8).write(to: url, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
}
