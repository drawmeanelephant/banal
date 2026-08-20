import AppKit
import Foundation

/// Parses incoming selection payloads from macOS Services into plain text.
public enum ServicesPasteboardParser {

    /// Extracts plain text from the provided pasteboard, checking standard text types.
    public static func extractText(from pasteboard: NSPasteboard) -> String? {
        let types: [NSPasteboard.PasteboardType] = [
            .string,
            NSPasteboard.PasteboardType("public.plain-text"),
            NSPasteboard.PasteboardType("NSStringPboardType"),
        ]

        for type in types {
            if let string = pasteboard.string(forType: type) {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return string
                }
            }
        }
        return nil
    }
}
