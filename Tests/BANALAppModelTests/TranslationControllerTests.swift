import BANALAppModel
import BANALCore
import XCTest

@MainActor
final class TranslationControllerTests: XCTestCase {
    func testCanTranslateRequiresNoteEditModeAndValidSelection() throws {
        let vault = try TestVault.make()
        defer { try? FileManager.default.removeItem(at: vault.rootURL) }
        let store = NoteStore(configuration: vault, monitor: nil)
        try store.open()
        let note = try store.createNote(title: "Alpha", body: "Some prose to translate.")

        let controller = TranslationController()
        let session = EditorSession()
        session.load(from: note, selectedID: note.id)
        session.selectedText = "Some prose"

        XCTAssertTrue(controller.canTranslate(session: session, hasSelectedNote: true, viewMode: .edit))
        XCTAssertFalse(controller.canTranslate(session: session, hasSelectedNote: false, viewMode: .edit))
        XCTAssertFalse(controller.canTranslate(session: session, hasSelectedNote: true, viewMode: .read))

        session.selectedText = ""
        XCTAssertFalse(controller.canTranslate(session: session, hasSelectedNote: true, viewMode: .edit))
    }

    func testTranslateSelectionPresentsSheetOnModernMacOS() throws {
        if #unavailable(macOS 15.0) {
            throw XCTSkip("the translation sheet requires macOS 15+")
        }
        let session = EditorSession()
        session.selectedText = "Bonjour"

        let controller = TranslationController()
        _ = controller.translateSelection(session: session)

        XCTAssertEqual(controller.text, "Bonjour")
        XCTAssertTrue(controller.isPresented)
    }

    func testReplaceSelectionRewritesBufferAndReports() {
        let session = EditorSession()
        session.editorText = "Replace THIS word"
        session.selectedRange = NSRange(location: 8, length: 4)

        let controller = TranslationController()
        let replaced = controller.replaceSelection(with: "that", session: session)

        XCTAssertTrue(replaced)
        XCTAssertEqual(session.editorText, "Replace that word")
        XCTAssertEqual(session.selectedText, "")
    }

    func testResetClearsPresentation() {
        let controller = TranslationController()
        controller.text = "Hola"
        controller.reset()
        XCTAssertEqual(controller.text, "")
        XCTAssertFalse(controller.isPresented)
    }
}
