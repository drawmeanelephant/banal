import AppKit
import Foundation
import UniformTypeIdentifiers

/// Quick Look preview provider for generating preview data payloads.
///
/// Provides fast, lightweight, native preview replies for Markdown, Cooklang, and Textile documents
/// without spawning long-running background engines or WebViews.
public enum NotePreviewProvider {

    /// Generate an RTF data payload for a given file URL.
    public static func rtfData(for fileURL: URL) -> Data? {
        let attributed = NotePreviewGenerator.attributedPreview(for: fileURL)
        let range = NSRange(location: 0, length: attributed.length)
        let docAttrs: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]
        return try? attributed.data(from: range, documentAttributes: docAttrs)
    }

    /// Generate an RTF data payload for note source and language.
    public static func rtfData(
        for source: String,
        language: NoteLanguage,
        title: String? = nil,
        directory: URL? = nil
    ) -> Data? {
        let attributed = NotePreviewGenerator.attributedPreview(for: source, language: language, fallbackTitle: title, directory: directory)
        let range = NSRange(location: 0, length: attributed.length)
        let docAttrs: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]
        return try? attributed.data(from: range, documentAttributes: docAttrs)
    }

    /// Generate plain text preview for a given file URL.
    public static func plainText(for fileURL: URL) -> String {
        NotePreviewGenerator.attributedPreview(for: fileURL).string
    }

    /// Generate plain text preview for note source and language.
    public static func plainText(
        for source: String,
        language: NoteLanguage,
        title: String? = nil,
        directory: URL? = nil
    ) -> String {
        NotePreviewGenerator.attributedPreview(for: source, language: language, fallbackTitle: title, directory: directory).string
    }
}
