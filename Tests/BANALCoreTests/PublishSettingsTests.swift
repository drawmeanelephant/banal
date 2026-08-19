import XCTest
@testable import BANALCore

final class PublishSettingsTests: XCTestCase {
    func testBaseURLAcceptsEmptyAndHTTP() {
        XCTAssertNil(PublishSettings.baseURLMessage(""))
        XCTAssertNil(PublishSettings.baseURLMessage("https://notes.example.com"))
        XCTAssertNil(PublishSettings.baseURLMessage("http://localhost:8788"))
        XCTAssertEqual(PublishSettings.baseURLMessage("notes.example.com"), "Use an http or https address.")
        XCTAssertEqual(PublishSettings.baseURLMessage("ftp://notes.example.com"), "Use an http or https address.")
        XCTAssertEqual(PublishSettings.baseURLMessage("https://"), "Use an http or https address.")
    }

    func testProjectNameIsCloudflareSafe() {
        XCTAssertNil(PublishSettings.projectNameMessage("banal-notes"))
        XCTAssertNil(PublishSettings.projectNameMessage("field-notes-2"))
        XCTAssertEqual(PublishSettings.projectNameMessage(""), "Enter a Cloudflare Pages project name.")
        XCTAssertEqual(
            PublishSettings.projectNameMessage("Field Notes"),
            "Use lowercase letters, numbers, and hyphens."
        )
        XCTAssertEqual(
            PublishSettings.projectNameMessage("-leading"),
            "Use lowercase letters, numbers, and hyphens."
        )
    }

    func testAccountIDWarnsWithoutBlocking() {
        XCTAssertNil(PublishSettings.accountIDMessage(""))
        XCTAssertNil(PublishSettings.accountIDMessage("0123456789abcdef0123456789abcdef"))
        XCTAssertEqual(
            PublishSettings.accountIDMessage("abc"),
            "Account IDs are usually 32 hex characters."
        )
        XCTAssertEqual(
            PublishSettings.accountIDMessage("gggggggggggggggggggggggggggggggg"),
            "Account IDs are usually 32 hex characters."
        )
    }

    func testVaultConfigRoundTripDoesNotStoreToken() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "banal-config-\(UUID().uuidString)",
            isDirectory: true
        )
        let configuration = VaultConfiguration(
            rootURL: root,
            siteTitle: "Field Notes",
            siteBaseURL: "https://notes.example.com",
            siteAuthor: "Ada",
            borisBinaryPath: "/opt/bin/boris",
            oliverBinaryPath: "/opt/bin/oliver",
            cloudflareAccountID: "0123456789abcdef0123456789abcdef",
            cloudflareProjectName: "field-notes",
            cloudflareCustomDomain: "notes.example.com"
        )
        try VaultBootstrap.prepare(configuration)
        try VaultBootstrap.save(configuration)
        defer { try? FileManager.default.removeItem(at: root) }

        let loaded = VaultBootstrap.load(from: root)
        XCTAssertEqual(loaded.siteTitle, "Field Notes")
        XCTAssertEqual(loaded.siteBaseURL, "https://notes.example.com")
        XCTAssertEqual(loaded.siteAuthor, "Ada")
        XCTAssertEqual(loaded.borisBinaryPath, "/opt/bin/boris")
        XCTAssertEqual(loaded.oliverBinaryPath, "/opt/bin/oliver")
        XCTAssertEqual(loaded.cloudflareProjectName, "field-notes")
        XCTAssertEqual(loaded.cloudflareAccountID, "0123456789abcdef0123456789abcdef")
        XCTAssertEqual(loaded.cloudflareCustomDomain, "notes.example.com")

        let raw = try String(contentsOf: configuration.configURL, encoding: .utf8)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        XCTAssertEqual(json["oliverBinaryPath"] as? String, "/opt/bin/oliver")
        XCTAssertEqual(json["borisBinaryPath"] as? String, "/opt/bin/boris")
        XCTAssertFalse(raw.lowercased().contains("token"))
        XCTAssertFalse(raw.contains("sk-"))
        XCTAssertFalse(raw.contains("apiToken"))
    }

    func testConfigWithoutOliverPathLoadsAsNil() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "banal-config-old-\(UUID().uuidString)",
            isDirectory: true
        )
        let configuration = VaultConfiguration(rootURL: root)
        try FileManager.default.createDirectory(at: configuration.metadataURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let legacy = """
        {
          "siteTitle" : "Notes",
          "siteBaseURL" : "",
          "siteAuthor" : "",
          "borisBinaryPath" : "/usr/local/bin/boris",
          "cloudflareProjectName" : "banal-notes",
          "cloudflareCustomDomain" : ""
        }
        """
        try Data(legacy.utf8).write(to: configuration.configURL, options: .atomic)

        let loaded = VaultBootstrap.load(from: root)
        XCTAssertEqual(loaded.borisBinaryPath, "/usr/local/bin/boris")
        XCTAssertNil(loaded.oliverBinaryPath)
    }
}
