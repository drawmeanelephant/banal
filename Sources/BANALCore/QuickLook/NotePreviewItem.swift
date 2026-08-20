import Foundation
import Quartz

/// A simple value type representing a note or recipe file URL for Quick Look presentation.
/// Use this to populate `QLPreviewPanel` from the note list in the app.
public final class NotePreviewItem: NSObject, QLPreviewItem, @unchecked Sendable {
    public let url: URL
    public let title: String

    public init(url: URL, title: String? = nil) {
        self.url = url
        self.title = title ?? url.deletingPathExtension().lastPathComponent
        super.init()
    }

    public init(note: Note) {
        self.url = note.fileURL
        self.title = note.displayTitle
        super.init()
    }

    @objc public var previewItemURL: URL? { url }
    @objc public var previewItemTitle: String? { title }
}
