import XCTest

final class HelpBookTests: XCTestCase {
    private let fileManager = FileManager.default

    private var repositoryRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        return url
    }

    private var helpBookRoot: URL {
        repositoryRoot.appendingPathComponent("Resources/BANAL.help")
    }

    private var helpPageURL: URL {
        helpBookRoot.appendingPathComponent("Contents/Resources/en.lproj/BANAL.html")
    }

    private func contents(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private func plist(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            XCTFail("not a dictionary plist: \(url.path)")
            return [:]
        }
        return plist
    }

    private func matches(in text: String, pattern: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let group = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[group])
        }
    }

    private var banalAppSource: URL {
        repositoryRoot.appendingPathComponent("Sources/BANALApp/BanalApp.swift")
    }

    private func codeBookName() throws -> String {
        let source = try contents(banalAppSource)
        let names = try matches(in: source, pattern: #"bookName\s*:\s*[^=]+=\s*"([^"]+)""#)
        return try XCTUnwrap(names.first, "BanalHelp.bookName not found in BanalApp.swift")
    }

    private func codeAnchors() throws -> [String] {
        let source = try contents(banalAppSource)
        let anchors = try matches(in: source, pattern: #"AnchorName\s*=\s*"([^"]+)""#)
        XCTAssertGreaterThanOrEqual(anchors.count, 1, "expected at least one AnchorName constant in BanalApp.swift")
        return anchors
    }

    private func htmlAnchors(_ html: String) throws -> Set<String> {
        let named = try matches(in: html, pattern: #"<a\s+name="([^"]+)""#)
        let identified = try matches(in: html, pattern: #"id="([^"]+)""#)
        return Set(named + identified)
    }

    func testHelpBookStructureExists() throws {
        XCTAssertTrue(fileManager.fileExists(atPath: repositoryRoot.appendingPathComponent("Package.swift").path),
                      "repository root not resolved from test file path")
        XCTAssertTrue(fileManager.fileExists(atPath: helpPageURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: helpBookRoot.appendingPathComponent("Contents/Info.plist").path))
    }

    func testBookNamesAgreeAcrossCodeAndPlists() throws {
        let bookName = try codeBookName()

        let appPlist = try plist(at: repositoryRoot.appendingPathComponent("Supporting/Info.plist"))
        XCTAssertEqual(appPlist["CFBundleHelpBookName"] as? String, bookName)

        let folder = try XCTUnwrap(appPlist["CFBundleHelpBookFolder"] as? String)
        XCTAssertEqual(folder, "BANAL.help")
        XCTAssertTrue(fileManager.fileExists(atPath: repositoryRoot.appendingPathComponent("Resources").appendingPathComponent(folder).path))

        let helpPlist = try plist(at: helpBookRoot.appendingPathComponent("Contents/Info.plist"))
        XCTAssertEqual(helpPlist["CFBundleIdentifier"] as? String, bookName)

        let projectYml = try contents(repositoryRoot.appendingPathComponent("Project.yml"))
        XCTAssertEqual(try matches(in: projectYml, pattern: #"INFOPLIST_KEY_CFBundleHelpBookName:\s*(\S+)"#).first, bookName)
        XCTAssertEqual(try matches(in: projectYml, pattern: #"INFOPLIST_KEY_CFBundleHelpBookFolder:\s*(\S+)"#).first, folder)
    }

    func testAnchorsReferencedFromCodeExistInHelpBook() throws {
        let html = try contents(helpPageURL)
        let available = try htmlAnchors(html)
        for anchor in try codeAnchors() {
            XCTAssertTrue(available.contains(anchor), "anchor '\(anchor)' referenced from BanalApp.swift is missing from BANAL.html")
        }
    }

    func testInPageNavigationLinksResolve() throws {
        let html = try contents(helpPageURL)
        let available = try htmlAnchors(html)
        let links = try matches(in: html, pattern: ##"href="#([^"]+)""##)
        XCTAssertFalse(links.isEmpty, "help table of contents should link to sections")
        for link in links {
            XCTAssertTrue(available.contains(link), "help nav link '#\(link)' has no matching anchor")
        }
    }

    func testHelpBookRegistersUnderExpectedTitle() throws {
        let html = try contents(helpPageURL)
        let titles = try matches(in: html, pattern: #"<meta\s+name="AppleTitle"\s+content="([^"]+)""#)
        XCTAssertEqual(titles.first, "BANAL Help")

        let helpPlist = try plist(at: helpBookRoot.appendingPathComponent("Contents/Info.plist"))
        XCTAssertEqual(helpPlist["HPDBookTitle"] as? String, "BANAL Help")

        let accessPath = try XCTUnwrap(helpPlist["HPDBookAccessPath"] as? String)
        XCTAssertTrue(fileManager.fileExists(atPath: helpBookRoot.appendingPathComponent("Contents/Resources/en.lproj").appendingPathComponent(accessPath).path))
    }
}
