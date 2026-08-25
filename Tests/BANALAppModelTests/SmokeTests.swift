import BANALAppModel
import XCTest

@MainActor
final class SmokeTests: XCTestCase {
    func testEditorSessionStartsClean() {
        let session = EditorSession()
        XCTAssertFalse(session.isDirty)
    }
}
