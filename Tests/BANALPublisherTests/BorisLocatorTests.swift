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
    func testInstalledAppHelperProbesAreMachineGlobalNotBundled() throws {
        // Installed-app probes are deliberately OUTSIDE executables(): they are
        // machine-global (any installed BANAL.app), so default-injection tests
        // must stay isolated from them. Shape: two fixed candidates, user-local
        // first, never present in the bundle-local list.
        let home = FileManager.default.homeDirectoryForCurrentUser
        let probes = BundledHelper.installedAppHelperURLs(named: "boris")
        XCTAssertEqual(probes.count, 2)
        XCTAssertTrue(probes[0].path.hasPrefix(home.appendingPathComponent("Applications").path + "/BANAL.app/Contents/Helpers/boris"))
        XCTAssertTrue(probes[1].path.hasPrefix("/Applications/BANAL.app/Contents/Helpers/boris"))
        let bundled = BundledHelper.executables(named: "boris")
        XCTAssertTrue(bundled.allSatisfy { !probes.map(\.standardizedFileURL).contains($0.standardizedFileURL) })
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

    // MARK: - Provenance (issue #223)
    //
    // `doctor` has to name the rung that answered, otherwise a green line
    // beside a bare CLI can bless a PATH copy while the app next to it runs
    // a different binary out of Contents/Helpers.

    func testDetailedNamesTheBundledRungWhenBundleWins() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundled = root.appendingPathComponent("bundled-boris")
        let binDir = root.appendingPathComponent("bin", isDirectory: true)
        let onPath = binDir.appendingPathComponent("boris")
        try makeStub(at: bundled)
        try makeStub(at: onPath)
        let found = BorisLocator.resolveDetailed(
            configured: nil,
            environment: ["PATH": binDir.path],
            currentDirectory: root,
            auxiliaryExecutables: { _ in [bundled] }
        )
        XCTAssertEqual(found?.url.standardizedFileURL, bundled.standardizedFileURL)
        XCTAssertEqual(found?.source, .bundled)
    }

    func testDetailedNamesThePathRungWhenNothingElseAnswers() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        // The PATH rung looks for a binary literally named "boris", and the
        // working-dir rung must not match, so isolate both.
        let binDir = root.appendingPathComponent("bin", isDirectory: true)
        let onPath = binDir.appendingPathComponent("boris")
        try makeStub(at: onPath)
        let found = BorisLocator.resolveDetailed(
            configured: nil,
            environment: ["PATH": binDir.path],
            currentDirectory: root,
            auxiliaryExecutables: { _ in [] }
        )
        XCTAssertEqual(found?.url.standardizedFileURL, onPath.standardizedFileURL)
        XCTAssertEqual(found?.source, .path)
    }

    func testDetailedNamesTheEnvironmentRung() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let env = root.appendingPathComponent("env-boris")
        try makeStub(at: env)
        let found = BorisLocator.resolveDetailed(
            configured: nil,
            environment: ["BANAL_BORIS_BIN": env.path, "PATH": ""],
            auxiliaryExecutables: { _ in [] }
        )
        XCTAssertEqual(found?.source, .environment)
    }

    func testDetailedNamesTheConfiguredRung() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let configured = root.appendingPathComponent("configured-boris")
        try makeStub(at: configured)
        let found = BorisLocator.resolveDetailed(
            configured: configured.path,
            environment: ["PATH": ""],
            auxiliaryExecutables: { _ in [] }
        )
        XCTAssertEqual(found?.source, .configured)
    }

    func testDetailedAgreesWithResolve() throws {
        let root = isolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundled = root.appendingPathComponent("bundled-boris")
        try makeStub(at: bundled)
        let env: [String: String] = ["PATH": ""]
        let detailed = BorisLocator.resolveDetailed(
            configured: nil, environment: env, auxiliaryExecutables: { _ in [bundled] }
        )
        let plain = BorisLocator.resolve(
            configured: nil, environment: env, auxiliaryExecutables: { _ in [bundled] }
        )
        XCTAssertEqual(detailed?.url, plain)
    }

    func testEveryEngineSourceHasALabel() {
        for source in EngineSource.allCases {
            XCTAssertFalse(source.label.isEmpty, "\(source) has no label")
        }
        XCTAssertEqual(EngineSource.installedApp.label, "installed app")
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
