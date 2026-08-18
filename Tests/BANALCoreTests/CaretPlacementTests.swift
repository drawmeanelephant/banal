import XCTest
@testable import BANALCore

final class CaretPlacementTests: XCTestCase {
    func testNewDocumentStartsAtZero() {
        let range = CaretPlacement.preferred(
            documentChanged: true,
            textUTF16Count: 80,
            previousLocation: 40,
            previousLength: 4
        )
        XCTAssertEqual(range, NSRange(location: 0, length: 0))
    }

    func testSameDocumentKeepsOffset() {
        let range = CaretPlacement.preferred(
            documentChanged: false,
            textUTF16Count: 80,
            previousLocation: 40,
            previousLength: 4
        )
        XCTAssertEqual(range, NSRange(location: 40, length: 4))
    }

    func testOffsetPastEndGoesToStart() {
        let range = CaretPlacement.preferred(
            documentChanged: false,
            textUTF16Count: 10,
            previousLocation: 40,
            previousLength: 0
        )
        XCTAssertEqual(range, NSRange(location: 0, length: 0))
    }

    func testSelectionClampedToNewLength() {
        let range = CaretPlacement.preferred(
            documentChanged: false,
            textUTF16Count: 12,
            previousLocation: 10,
            previousLength: 8
        )
        XCTAssertEqual(range, NSRange(location: 10, length: 2))
    }
}
