@testable import BANALCore
import Foundation
import Testing

@Suite("Accessibility Formatting Tests (F-7)")
struct AccessibilityFormattingTests {

    @Test("Note count pluralization formats properly")
    func testNoteCountPluralization() {
        #expect(AccessibilityFormatting.noteCount(0) == "0 notes")
        #expect(AccessibilityFormatting.noteCount(1) == "1 note")
        #expect(AccessibilityFormatting.noteCount(2) == "2 notes")
        #expect(AccessibilityFormatting.noteCount(42) == "42 notes")
    }

    @Test("Published note count formats with pluralization")
    func testPublishedNoteCount() {
        #expect(AccessibilityFormatting.publishedNoteCount(0) == "0 published notes")
        #expect(AccessibilityFormatting.publishedNoteCount(1) == "1 published note")
        #expect(AccessibilityFormatting.publishedNoteCount(5) == "5 published notes")
    }

    @Test("Folder note count formats properly")
    func testFolderNoteCount() {
        #expect(AccessibilityFormatting.folderNoteCount(0) == "0 notes")
        #expect(AccessibilityFormatting.folderNoteCount(1) == "1 note")
        #expect(AccessibilityFormatting.folderNoteCount(3) == "3 notes")
    }

    @Test("Note row description includes all attributes when populated")
    func testNoteRowDescriptionFull() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let desc = AccessibilityFormatting.noteRowDescription(
            title: "Saffron Risotto",
            folder: "Recipes",
            isRecipe: true,
            isPublished: true,
            updatedDate: date,
            snippet: "Add arborio rice and stir well."
        )

        #expect(desc.contains("Saffron Risotto"))
        #expect(desc.contains("Folder: Recipes"))
        #expect(desc.contains("Recipe"))
        #expect(desc.contains("Published"))
        #expect(desc.contains("Add arborio rice and stir well."))
    }

    @Test("Note row description omits empty fields")
    func testNoteRowDescriptionMinimal() {
        let date = Date()
        let desc = AccessibilityFormatting.noteRowDescription(
            title: "Quick Thought",
            folder: nil,
            isRecipe: false,
            isPublished: false,
            updatedDate: date,
            snippet: ""
        )

        #expect(desc.contains("Quick Thought"))
        #expect(!desc.contains("Folder:"))
        #expect(!desc.contains("Recipe"))
        #expect(!desc.contains("Published"))
    }

    @Test("Recipe step, note, and section announcements format cleanly")
    func testRecipeAnnouncements() {
        #expect(AccessibilityFormatting.recipeStep(number: 1, text: "Heat pan on medium.") == "Step 1: Heat pan on medium.")
        #expect(AccessibilityFormatting.recipeStep(number: 3, text: "Add stock gradually.") == "Step 3: Add stock gradually.")
        #expect(AccessibilityFormatting.recipeNote("Stir continuously until glossy.") == "Note: Stir continuously until glossy.")
        #expect(AccessibilityFormatting.recipeSection("For the broth") == "Section: For the broth")
    }
}
