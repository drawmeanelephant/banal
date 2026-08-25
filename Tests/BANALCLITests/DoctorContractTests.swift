import XCTest
@testable import BANALCLI

// The CLI is a thin adapter over BANALCore/BANALPublisher; its one piece of
// own logic is the doctor contract mirror. These tests pin it to Boris's
// identity contract (docs/contracts/identity-and-paths.md rule 2) so drift
// on either side shows up in CI.
final class DoctorContractTests: XCTestCase {
    func testConformingIDsPass() {
        for id in ["hello", "Recipes/Sunday-Sauce", "Café-Notes", "hello-2", "a/b/c"] {
            XCTAssertTrue(BanalCLI.Doctor.borisConforming(id), "expected conforming: \(id)")
        }
    }

    func testRejectedClassesFail() {
        for id in ["Published Note", "What?", "100%", "back\\slash", "a\\b", "",
                   "/leading", "trailing/", "trailing\\", ".", "..", "a/./b", "a/../b",
                   "a//b", String(repeating: "x", count: 256)] {
            XCTAssertFalse(BanalCLI.Doctor.borisConforming(id), "expected rejection: \(id)")
        }
    }

    func testUnicodeWhitespaceIsRejected() {
        // Swift isWhitespace is stricter than Boris's ASCII set; the safe direction.
        for id in ["café\u{00A0}notes", "tab\there"] {
            XCTAssertFalse(BanalCLI.Doctor.borisConforming(id), "expected rejection: \(id)")
        }
    }
}
