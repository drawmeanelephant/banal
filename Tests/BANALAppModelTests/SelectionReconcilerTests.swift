import XCTest
@testable import BANALAppModel

final class SelectionReconcilerTests: XCTestCase {
    func testSelectionStillVisibleStays() {
        let target = SelectionReconciler.target(selectedID: "b", visibleIDs: ["a", "b", "c"])
        XCTAssertEqual(target, "b")
    }

    func testSelectionNotVisibleFallsToFirst() {
        // Switching from a folder whose note was "z" into a folder with notes.
        let target = SelectionReconciler.target(selectedID: "z", visibleIDs: ["r1", "r2"])
        XCTAssertEqual(target, "r1")
    }

    func testEmptyVisibleListClearsSelection() {
        // Empty folder, Published with nothing published, search with no matches.
        let target = SelectionReconciler.target(selectedID: "z", visibleIDs: [])
        XCTAssertNil(target)
    }

    func testNilSelectionWithNotesPicksFirst() {
        // Coming out of an empty folder back into a populated one.
        let target = SelectionReconciler.target(selectedID: nil, visibleIDs: ["n1", "n2"])
        XCTAssertEqual(target, "n1")
    }

    func testNilSelectionWithNoNotesStaysNil() {
        let target = SelectionReconciler.target(selectedID: nil, visibleIDs: [])
        XCTAssertNil(target)
    }
}
