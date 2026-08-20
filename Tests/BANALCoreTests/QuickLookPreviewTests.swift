import AppKit
import XCTest
@testable import BANALCore

final class QuickLookPreviewTests: XCTestCase {

    func testMarkdownPreview() {
        let source = """
        ---
        title: Test Document
        tags: [journal, test]
        created: 2026-08-19
        ---

        # Main Heading

        This is a paragraph with **bold** text, *italic* text, and `inline code`.

        - First item
        - Second item with **emphasis**

        1. Numbered one
        2. Numbered two

        > A quiet quote from someone.

        ```swift
        let x = 42
        ```
        """

        let attr = NotePreviewGenerator.attributedPreview(for: source, language: .markdown)
        let text = attr.string

        XCTAssertTrue(text.contains("Test Document"))
        XCTAssertTrue(text.contains("2026-08-19 · journal, test"))
        XCTAssertTrue(text.contains("Main Heading"))
        XCTAssertTrue(text.contains("This is a paragraph with bold text, italic text, and inline code."))
        XCTAssertTrue(text.contains("•\tFirst item"))
        XCTAssertTrue(text.contains("•\tSecond item with emphasis"))
        XCTAssertTrue(text.contains("1.\tNumbered one"))
        XCTAssertTrue(text.contains("2.\tNumbered two"))
        XCTAssertTrue(text.contains("“\tA quiet quote from someone.”"))
        XCTAssertTrue(text.contains("let x = 42"))
    }

    func testCooklangRecipePreview() {
        let source = """
        >> title: Classic Risotto
        >> servings: 4
        >> time: 35 minutes
        >> tags: dinner, rice

        In a #pan{}, heat @olive oil{2%tbsp} and sauté @onion{1%medium}.

        Add @carnaroli rice{300%g} and toast for ~{2%minutes}.

        Pour in @white wine{100%ml} and simmer until evaporated.

        Gradually add @vegetable stock{1%L} while stirring.

        Finish with @butter{50%g} and @parmesan cheese{50%g}.
        """

        let model = NotePreviewGenerator.recipePreview(for: source)
        XCTAssertEqual(model.title, "Classic Risotto")
        XCTAssertEqual(model.metadata["servings"], "4")
        XCTAssertEqual(model.metadata["time"], "35 minutes")
        XCTAssertEqual(model.tags, ["dinner", "rice"])
        XCTAssertEqual(model.cookware, ["pan"])

        let ingNames = model.ingredients.map(\.name)
        XCTAssertTrue(ingNames.contains("olive oil"))
        XCTAssertTrue(ingNames.contains("onion"))
        XCTAssertTrue(ingNames.contains("carnaroli rice"))
        XCTAssertTrue(ingNames.contains("white wine"))
        XCTAssertTrue(ingNames.contains("vegetable stock"))
        XCTAssertTrue(ingNames.contains("butter"))
        XCTAssertTrue(ingNames.contains("parmesan cheese"))

        let attr = NotePreviewGenerator.attributedPreview(for: source, language: .cooklang)
        let text = attr.string
        XCTAssertTrue(text.contains("Classic Risotto"))
        XCTAssertTrue(text.contains("Servings: 4 · Time: 35 minutes · dinner, rice"))
        XCTAssertTrue(text.contains("Ingredients"))
        XCTAssertTrue(text.contains("2 tbsp olive oil"))
        XCTAssertTrue(text.contains("1 medium onion"))
        XCTAssertTrue(text.contains("300 g carnaroli rice"))
        XCTAssertTrue(text.contains("100 ml white wine"))
        XCTAssertTrue(text.contains("1 L vegetable stock"))
        XCTAssertTrue(text.contains("50 g butter"))
        XCTAssertTrue(text.contains("50 g parmesan cheese"))
        XCTAssertTrue(text.contains("Instructions"))
        XCTAssertTrue(text.contains("1.\tIn a pan, heat olive oil and sauté onion."))
        XCTAssertTrue(text.contains("2.\tAdd carnaroli rice and toast for 2 minutes."))
    }

    func testCooklangSauceReference() {
        let source = """
        >> title: Eggs Benedict

        Toast the English muffins. Poach the eggs.

        Top with @./sauces/hollandaise{100%g}.
        """

        let model = NotePreviewGenerator.recipePreview(for: source)
        XCTAssertEqual(model.title, "Eggs Benedict")
        let sauceIng = model.ingredients.first(where: { $0.isSauceReference })
        XCTAssertNotNil(sauceIng)
        XCTAssertEqual(sauceIng?.quantity, "100")
        XCTAssertEqual(sauceIng?.unit, "g")
    }

    func testTextilePreview() {
        let source = """
        ---
        title: Textile Page
        tags: [web, reference]
        ---

        h1. Heading One
        h2. Subheading Two

        A paragraph with *bold text* and _italic text_ plus @code snippet@.

        * Item A
        * Item B

        bc. 
        struct Note {
            let id: String
        }
        """

        let attr = NotePreviewGenerator.attributedPreview(for: source, language: .textile)
        let text = attr.string

        XCTAssertTrue(text.contains("Textile Page"))
        XCTAssertTrue(text.contains("web, reference"))
        XCTAssertTrue(text.contains("Heading One"))
        XCTAssertTrue(text.contains("Subheading Two"))
        XCTAssertTrue(text.contains("A paragraph with bold text and italic text plus code snippet."))
        XCTAssertTrue(text.contains("•\tItem A"))
        XCTAssertTrue(text.contains("•\tItem B"))
        XCTAssertTrue(text.contains("struct Note"))
    }

    func testNotePreviewItem() {
        let url = URL(fileURLWithPath: "/tmp/sample.cook")
        let item = NotePreviewItem(url: url, title: "Sample Recipe")
        XCTAssertEqual(item.previewItemURL, url)
        XCTAssertEqual(item.previewItemTitle, "Sample Recipe")

        let note = Note(
            id: "recipes/risotto.cook",
            fileURL: url,
            title: "Risotto",
            body: "Add @rice{200%g}.",
            created: Date(),
            updated: Date(),
            tags: ["dinner"],
            published: true,
            modifiedAt: Date()
        )
        let noteItem = NotePreviewItem(note: note)
        XCTAssertEqual(noteItem.previewItemURL, url)
        XCTAssertEqual(noteItem.previewItemTitle, "Risotto")
    }

    func testNotePreviewProviderRTF() {
        let source = """
        # Hello QuickLook

        Testing system preview reply.
        """
        let data = NotePreviewProvider.rtfData(for: source, language: .markdown, title: "Hello QuickLook")
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 0)
    }

    func testNotePreviewProviderPlainText() {
        let source = """
        >> title: Simple Salad

        Mix @lettuce{1%head} and @tomatoes{2}.
        """
        let plain = NotePreviewProvider.plainText(for: source, language: .cooklang)
        XCTAssertTrue(plain.contains("Simple Salad"))
        XCTAssertTrue(plain.contains("Ingredients"))
        XCTAssertTrue(plain.contains("1 head lettuce"))
    }

    func testEmptyAndFallbackPreviews() {
        let emptyAttr = NotePreviewGenerator.attributedPreview(for: "", language: .markdown, fallbackTitle: "Empty")
        XCTAssertTrue(emptyAttr.string.contains("Empty"))

        let invalidURL = URL(fileURLWithPath: "/nonexistent/path/note.md")
        let fallbackAttr = NotePreviewGenerator.attributedPreview(for: invalidURL)
        XCTAssertTrue(fallbackAttr.string.contains("note"))
        XCTAssertTrue(fallbackAttr.string.contains("Unable to read note file."))
    }
}
