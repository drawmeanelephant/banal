import Foundation

/// Generates share sheet items and text payloads for BANAL notes.
public enum NoteSharePayload {

    /// Returns the sharing items for a given note: the note file URL and plain text body.
    public static func items(for note: Note) -> [Any] {
        var items: [Any] = []
        if FileManager.default.fileExists(atPath: note.fileURL.path) {
            items.append(note.fileURL)
        }
        let text = plainTextPayload(for: note)
        if !text.isEmpty {
            items.append(text)
        }
        return items
    }

    /// Generates a clean plain text representation of the note.
    public static func plainTextPayload(for note: Note) -> String {
        let title = note.displayTitle
        let body = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty {
            return title
        }
        if note.language == .cooklang || body.hasPrefix(title) {
            return body
        }
        return "\(title)\n\n\(body)"
    }
}
