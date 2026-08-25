import BANALCore
import Foundation
import XCTest
@testable import BANALCLI

// The CLI is a thin adapter over BANALCore/BANALPublisher; its one piece of
// own logic is the doctor contract mirror. These tests pin it to Boris's
// identity contract (docs/contracts/identity-and-paths.md rule 2) so drift
// on either side shows up in CI.
final class DoctorContractTests: XCTestCase {
    func testConformingIDsPass() {
        let cases = [
            "hello",
            "Recipes/Sunday-Sauce",
            "Café-Notes",
            "hello-2",
            "a/b/c",
            "a",
            "123",
            "a-b_c",
            String(repeating: "a", count: 255),
            // 85 3-byte unicode characters (85 * 3 = 255 UTF-8 bytes)
            String(repeating: "€", count: 85),
        ]
        for id in cases {
            XCTAssertTrue(BanalCLI.Doctor.borisConforming(id), "expected conforming: \(id)")
        }
    }

    func testRejectedClassesFail() {
        let cases = [
            "Published Note", "What?", "100%", "back\\slash", "a\\b", "",
            "/", "//", "/leading", "trailing/", "trailing\\", "\\leading",
            ".", "..", "a/./b", "a/../b", "../a", "a/..",
            "a//b", "a///b", "tag#name",
            String(repeating: "x", count: 256),
            // 86 3-byte unicode characters (86 * 3 = 258 UTF-8 bytes)
            String(repeating: "€", count: 86),
        ]
        for id in cases {
            XCTAssertFalse(BanalCLI.Doctor.borisConforming(id), "expected rejection: \(id)")
        }
    }

    func testUnicodeWhitespaceIsRejected() {
        // Swift isWhitespace is stricter than Boris's ASCII set; the safe direction.
        for id in ["café\u{00A0}notes", "tab\there", "line\nbreak", "return\rhere"] {
            XCTAssertFalse(BanalCLI.Doctor.borisConforming(id), "expected rejection: \(id)")
        }
    }
}

final class NoteJSONLineTests: XCTestCase {
    func testNoteJSONLineKeysAndFormatting() {
        let created = Date(timeIntervalSince1970: 1700000000)
        let updated = Date(timeIntervalSince1970: 1700003600)
        let note = Note(
            id: "Recipes/Risotto.cook",
            fileURL: URL(fileURLWithPath: "/tmp/Recipes/Risotto.cook"),
            title: "Risotto",
            body: "Stir broth.",
            created: created,
            updated: updated,
            tags: ["dinner", "italian"],
            published: true,
            modifiedAt: updated,
            fileSize: 42
        )
        let json = note.jsonLine
        XCTAssertEqual(json["id"] as? String, "Recipes/Risotto.cook")
        XCTAssertEqual(json["title"] as? String, "Risotto")
        XCTAssertEqual(json["language"] as? String, "cooklang")
        XCTAssertEqual(json["published"] as? Bool, true)
        XCTAssertEqual(json["tags"] as? [String], ["dinner", "italian"])
        XCTAssertEqual(json["bytes"] as? Int, 42)
        XCTAssertEqual(json["created"] as? String, "2023-11-14T22:13:20Z")
        XCTAssertEqual(json["updated"] as? String, "2023-11-14T23:13:20Z")
    }

    func testNoteJSONLineWithNilFileSizeDefaultsToZeroBytes() {
        let now = Date(timeIntervalSince1970: 1700000000)
        let note = Note(
            id: "Inbox/Draft.md",
            fileURL: URL(fileURLWithPath: "/tmp/Inbox/Draft.md"),
            title: "Draft",
            body: "Hello",
            created: now,
            updated: now,
            modifiedAt: now,
            fileSize: nil
        )
        let json = note.jsonLine
        XCTAssertEqual(json["bytes"] as? Int, 0)
        XCTAssertEqual(json["published"] as? Bool, false)
        XCTAssertEqual(json["tags"] as? [String], [])
    }
}


