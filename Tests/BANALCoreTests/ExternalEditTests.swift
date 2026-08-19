import XCTest
@testable import BANALCore

final class ExternalEditTests: XCTestCase {
    func testCleanDiskChangeReloads() {
        let action = ExternalEdit.action(
            selectedStillOnDisk: true,
            dirty: false,
            loadedFingerprint: "aaa",
            diskFingerprint: "bbb",
            bufferMatchesDisk: false
        )
        XCTAssertEqual(action, .reload)
    }

    func testDirtyDiskChangeKeepsBuffer() {
        let action = ExternalEdit.action(
            selectedStillOnDisk: true,
            dirty: true,
            loadedFingerprint: "aaa",
            diskFingerprint: "bbb",
            bufferMatchesDisk: false
        )
        XCTAssertEqual(action, .keepBuffer)
    }

    func testOurOwnSaveIsIgnored() {
        let action = ExternalEdit.action(
            selectedStillOnDisk: true,
            dirty: true,
            loadedFingerprint: "aaa",
            diskFingerprint: "bbb",
            bufferMatchesDisk: true
        )
        XCTAssertEqual(action, .ignore)
    }

    func testUnchangedDiskIsIgnored() {
        let action = ExternalEdit.action(
            selectedStillOnDisk: true,
            dirty: false,
            loadedFingerprint: "aaa",
            diskFingerprint: "aaa",
            bufferMatchesDisk: false
        )
        XCTAssertEqual(action, .ignore)
    }

    func testGoneWhileDirtyKeepsBuffer() {
        let action = ExternalEdit.action(
            selectedStillOnDisk: false,
            dirty: true,
            loadedFingerprint: "aaa",
            diskFingerprint: "",
            bufferMatchesDisk: false
        )
        XCTAssertEqual(action, .noteGone(keepBuffer: true))
    }

    func testGoneWhileCleanLeaves() {
        let action = ExternalEdit.action(
            selectedStillOnDisk: false,
            dirty: false,
            loadedFingerprint: "aaa",
            diskFingerprint: "",
            bufferMatchesDisk: false
        )
        XCTAssertEqual(action, .noteGone(keepBuffer: false))
    }

    func testKeepBufferWinsOverASecondDiskFingerprint() {
        let first = ExternalEdit.action(
            selectedStillOnDisk: true,
            dirty: true,
            loadedFingerprint: "aaa",
            diskFingerprint: "bbb",
            bufferMatchesDisk: false
        )
        let second = ExternalEdit.action(
            selectedStillOnDisk: true,
            dirty: true,
            loadedFingerprint: "aaa",
            diskFingerprint: "ccc",
            bufferMatchesDisk: false
        )
        XCTAssertEqual(first, .keepBuffer)
        XCTAssertEqual(second, .keepBuffer)
    }

    func testWritingToolsActiveSuppressesReloadOnCleanBuffer() {
        let action = ExternalEdit.action(
            selectedStillOnDisk: true,
            dirty: false,
            loadedFingerprint: "aaa",
            diskFingerprint: "bbb",
            bufferMatchesDisk: false,
            isWritingToolsActive: true
        )
        XCTAssertEqual(action, .keepBuffer, "Writing Tools active must suppress reloading from disk")
    }

    func testWritingToolsActiveKeepsBufferOnDirtyDiskChange() {
        let action = ExternalEdit.action(
            selectedStillOnDisk: true,
            dirty: true,
            loadedFingerprint: "aaa",
            diskFingerprint: "bbb",
            bufferMatchesDisk: false,
            isWritingToolsActive: true
        )
        XCTAssertEqual(action, .keepBuffer)
    }
}
