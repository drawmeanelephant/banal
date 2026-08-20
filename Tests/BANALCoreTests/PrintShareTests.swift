import AppKit
@testable import BANALCore
import Foundation
import Testing

@Suite("Print, Share, and Services Tests (F-5)")
struct PrintShareTests {

    @Test("Markdown note print formatting contains title, metadata, and formatted elements")
    func testMarkdownPrintFormatting() {
        let source = """
        ---
        title: Project Roadmap
        tags: [planning, mac]
        ---

        # Overview
        This is a **bold** paragraph with `code` and _italic_ text.

        > A great quote about simplicity.

        - First bullet item
        - Second bullet item

        1. Step one
        2. Step two

        ```swift
        let x = 42
        ```
        """

        let note = Note(
            id: "roadmap.md",
            fileURL: URL(fileURLWithPath: "/tmp/vault/roadmap.md"),
            title: "Project Roadmap",
            body: source,
            created: Date(timeIntervalSince1970: 1700000000),
            updated: Date(timeIntervalSince1970: 1700000000),
            tags: ["planning", "mac"],
            modifiedAt: Date()
        )

        let attr = NotePrintFormatter.attributedString(for: note, isRecipeReadMode: false)
        let plain = attr.string

        #expect(plain.contains("Project Roadmap"))
        #expect(plain.contains("mac, planning"))
        #expect(plain.contains("Overview"))
        #expect(plain.contains("bold"))
        #expect(plain.contains("A great quote about simplicity."))
        #expect(plain.contains("First bullet item"))
        #expect(plain.contains("Step one"))
        #expect(plain.contains("let x = 42"))
    }

    @Test("Textile note print formatting contains title and headings")
    func testTextilePrintFormatting() {
        let source = """
        h1. Meeting Notes

        p. Here is the discussion from today.

        * Action item 1
        * Action item 2

        bc. let code = \"hello\"
        """

        let note = Note(
            id: "meeting.textile",
            fileURL: URL(fileURLWithPath: "/tmp/vault/meeting.textile"),
            title: "Meeting Notes",
            body: source,
            created: Date(),
            updated: Date(),
            modifiedAt: Date()
        )

        let attr = NotePrintFormatter.attributedString(for: note, isRecipeReadMode: false)
        let plain = attr.string

        #expect(plain.contains("Meeting Notes"))
        #expect(plain.contains("Here is the discussion from today."))
        #expect(plain.contains("Action item 1"))
        #expect(plain.contains("let code = \"hello\""))
    }

    @Test("Cooklang recipe print formatting contains ingredients, cookware, steps, and scale")
    func testCooklangRecipePrintFormatting() {
        let source = """
        >> title: Saffron Risotto
        >> servings: 4
        >> time: 35 minutes
        >> tags: dinner, italian

        Add @carnaroli rice{320%g} and @butter{40%g} to the #pan{}.

        Stir in @vegetable stock{1%L} and @saffron{1%pinch}.

        Serve hot.
        """

        let note = Note(
            id: "Recipes/risotto.cook",
            fileURL: URL(fileURLWithPath: "/tmp/vault/Recipes/risotto.cook"),
            title: "Saffron Risotto",
            body: source,
            created: Date(),
            updated: Date(),
            tags: ["dinner", "italian"],
            modifiedAt: Date()
        )

        let attr = NotePrintFormatter.attributedString(
            for: note,
            isRecipeReadMode: true,
            scaleLabel: "2×"
        )
        let plain = attr.string

        #expect(plain.contains("Saffron Risotto"))
        #expect(plain.contains("Scale: 2×"))
        #expect(plain.contains("Servings: 4"))
        #expect(plain.contains("Time: 35 minutes"))
        #expect(plain.contains("Ingredients"))
        #expect(plain.contains("carnaroli rice"))
        #expect(plain.contains("butter"))
        #expect(plain.contains("Cookware"))
        #expect(plain.contains("pan"))
        #expect(plain.contains("Instructions"))
        #expect(plain.contains("Serve hot."))
    }

    @Test("NoteSharePayload generates file URL and plain text payload")
    func testNoteSharePayload() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("shared.md")
        try? "Shared body text content.".write(to: fileURL, atomically: true, encoding: .utf8)

        let note = Note(
            id: "shared.md",
            fileURL: fileURL,
            title: "Shared Note",
            body: "Shared body text content.",
            created: Date(),
            updated: Date(),
            modifiedAt: Date()
        )

        let items = NoteSharePayload.items(for: note)
        #expect(items.count == 2)

        let hasURL = items.contains { ($0 as? URL) == fileURL }
        #expect(hasURL)

        let textPayload = NoteSharePayload.plainTextPayload(for: note)
        #expect(textPayload.contains("Shared Note"))
        #expect(textPayload.contains("Shared body text content."))
    }


    @Test("Print operation setup configures margins, pagination, and printable view")
    @MainActor func testPrintOperationSetup() {
        let note = Note(
            id: "print-test.md",
            fileURL: URL(fileURLWithPath: "/tmp/vault/print-test.md"),
            title: "Printable Note",
            body: "# Printable Note\n\nClean Mac print test.",
            created: Date(),
            updated: Date(),
            modifiedAt: Date()
        )

        let attributed = NotePrintFormatter.attributedString(for: note, isRecipeReadMode: false)
        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36

        let printableWidth = max(200, printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin)
        let printableHeight = max(200, printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin)

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: printableWidth, height: printableHeight))
        textView.appearance = NSAppearance(named: .aqua)
        textView.textStorage?.setAttributedString(attributed)

        let op = NSPrintOperation(view: textView, printInfo: printInfo)
        op.showsPrintPanel = true
        op.showsProgressPanel = true

        #expect(op.printInfo.horizontalPagination == .fit)
        #expect(op.printInfo.leftMargin == 36)
        #expect(op.printInfo.rightMargin == 36)
        #expect(op.showsPrintPanel == true)
        #expect(op.showsProgressPanel == true)
        #expect((op.view as? NSTextView)?.string.contains("Printable Note") == true)
    }

    @Test("Service pasteboard creation workflow creates note in Inbox folder")
    @MainActor func testServicePasteboardNoteCreationWorkflow() throws {
        let tempVault = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempVault, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempVault) }

        let store = NoteStore(configuration: VaultConfiguration(rootURL: tempVault))
        try store.open()

        let serviceText = "Safari Selected Article\n\nHere is the captured paragraph."
        let resolvedTitle = inferredTitle(from: serviceText) ?? "Note"
        let note = try store.createNote(
            title: resolvedTitle,
            body: serviceText,
            folder: "Inbox",
            language: .markdown
        )

        #expect(note.title == "Safari Selected Article")
        #expect(note.folder == "Inbox")
        #expect(note.body == serviceText)
        #expect(FileManager.default.fileExists(atPath: note.fileURL.path))
    }

    @Test("ServicesPasteboardParser extracts valid text and ignores empty strings")
    func testServicesPasteboardParser() {
        let pb = NSPasteboard.withUniqueName()
        pb.clearContents()
        pb.setString("Text selected in Safari", forType: .string)

        let extracted = ServicesPasteboardParser.extractText(from: pb)
        #expect(extracted == "Text selected in Safari")

        let emptyPB = NSPasteboard.withUniqueName()
        emptyPB.clearContents()
        emptyPB.setString("   \n\t  ", forType: .string)
        #expect(ServicesPasteboardParser.extractText(from: emptyPB) == nil)

        let blankPB = NSPasteboard.withUniqueName()
        blankPB.clearContents()
        #expect(ServicesPasteboardParser.extractText(from: blankPB) == nil)
    }
}
