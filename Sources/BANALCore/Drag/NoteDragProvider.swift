import Foundation
import UniformTypeIdentifiers

/// Creates `NSItemProvider` instances for dragging notes out of BANAL or internally between folders.
public enum NoteDragProvider {

    /// Builds an `NSItemProvider` configured with:
    /// 1. File URL representation pointing to `note.fileURL` on disk (for Finder, Mail file attachments, etc.)
    /// 2. Plain text representation containing the note's formatted text (for Mail body, Messages, TextEdit, etc.)
    public static func itemProvider(for note: Note) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = note.fileURL.lastPathComponent

        // 1. File URL representation pointing to the note file on disk
        provider.registerItem(forTypeIdentifier: UTType.fileURL.identifier) { completionHandler, _, _ in
            completionHandler?(note.fileURL as NSURL, nil)
        }

        // 2. Plain text representation
        let textPayload = NoteSharePayload.plainTextPayload(for: note)
        provider.registerItem(forTypeIdentifier: UTType.utf8PlainText.identifier) { completionHandler, _, _ in
            completionHandler?(textPayload as NSString, nil)
        }
        provider.registerItem(forTypeIdentifier: UTType.plainText.identifier) { completionHandler, _, _ in
            completionHandler?(textPayload as NSString, nil)
        }

        return provider
    }
}
