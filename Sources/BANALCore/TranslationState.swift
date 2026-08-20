import Foundation

/// Core state and utilities for translation sessions.
public struct TranslationState: Equatable, Sendable {
    public var selectedText: String
    public var selectedRange: NSRange
    public var isPresented: Bool
    public var translationText: String

    public init(
        selectedText: String = "",
        selectedRange: NSRange = NSRange(location: 0, length: 0),
        isPresented: Bool = false,
        translationText: String = ""
    ) {
        self.selectedText = selectedText
        self.selectedRange = selectedRange
        self.isPresented = isPresented
        self.translationText = translationText
    }

    /// Whether translation can be performed on the current selection.
    /// Requires non-empty, non-whitespace text.
    public var canTranslate: Bool {
        Self.isValidTranslationText(selectedText)
    }

    /// Validates if the given text is non-empty and contains non-whitespace characters.
    public static func isValidTranslationText(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Safely extracts the selected substring from a string given an NSRange.
    /// Handles UTF-16 offsets and boundary conditions.
    public static func extractSelectedText(from string: String, range: NSRange) -> String? {
        guard range.location != NSNotFound, range.length > 0 else {
            return nil
        }
        let nsString = string as NSString
        guard range.location >= 0,
              range.location + range.length <= nsString.length else {
            return nil
        }
        return nsString.substring(with: range)
    }

    /// Replaces the characters at the specified range with replacement text.
    /// Returns the updated string and the new caret location.
    public static func replaceSelectedText(
        in string: String,
        range: NSRange,
        with replacement: String
    ) -> (result: String, newRange: NSRange)? {
        guard range.location != NSNotFound else { return nil }
        let nsString = string as NSString
        guard range.location >= 0,
              range.location + range.length <= nsString.length else {
            return nil
        }
        let result = nsString.replacingCharacters(in: range, with: replacement)
        let newLocation = range.location + (replacement as NSString).length
        let newRange = NSRange(location: newLocation, length: 0)
        return (result, newRange)
    }

    /// System translation availability helper.
    public static var isSystemTranslationSupported: Bool {
        if #available(macOS 15.0, *) {
            return true
        } else {
            return false
        }
    }
}
