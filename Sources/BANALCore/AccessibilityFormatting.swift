import Foundation

/// Utilities for consistent, natural VoiceOver labels across BANAL.
public enum AccessibilityFormatting {
    /// Formats note count with pluralization (e.g. "0 notes", "1 note", "5 notes").
    public static func noteCount(_ count: Int) -> String {
        count == 1 ? "1 note" : "\(count) notes"
    }

    /// Formats published note count (e.g. "0 published notes", "1 published note", "5 published notes").
    public static func publishedNoteCount(_ count: Int) -> String {
        count == 1 ? "1 published note" : "\(count) published notes"
    }

    /// Formats a folder item's accessibility value (e.g. "5 notes").
    public static func folderNoteCount(_ count: Int) -> String {
        count == 1 ? "1 note" : "\(count) notes"
    }

    /// Formats note row spoken description for VoiceOver.
    /// Includes title, folder location, language type, publish status, relative date, and preview snippet.
    public static func noteRowDescription(
        title: String,
        folder: String? = nil,
        isRecipe: Bool = false,
        isPublished: Bool = false,
        updatedDate: Date,
        snippet: String = ""
    ) -> String {
        var parts: [String] = [title]
        if let folder, !folder.isEmpty {
            parts.append("Folder: \(folder)")
        }
        if isRecipe {
            parts.append("Recipe")
        }
        if isPublished {
            parts.append("Published")
        }
        parts.append(updatedDate.formatted(.relative(presentation: .named)))
        let trimmedSnippet = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSnippet.isEmpty {
            parts.append(trimmedSnippet)
        }
        return parts.joined(separator: ", ")
    }

    /// Formats a recipe step description for VoiceOver (e.g. "Step 1: Add rice to the pan.").
    public static func recipeStep(number: Int, text: String) -> String {
        "Step \(number): \(text)"
    }

    /// Formats a recipe note description for VoiceOver (e.g. "Note: Stir continuously.").
    public static func recipeNote(_ text: String) -> String {
        "Note: \(text)"
    }

    /// Formats a recipe section header for VoiceOver (e.g. "Section: For the broth").
    public static func recipeSection(_ name: String) -> String {
        "Section: \(name)"
    }
}
