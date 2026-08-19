import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Utilities for smart paste behavior: wrapping selections in Markdown links
/// when pasting URLs, and converting rich text / HTML into clean Markdown.
public enum SmartPaste {
    /// Validates if a string is a valid standalone `http://` or `https://` URL.
    public static func isHTTPURL(_ string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Ensure there are no spaces or newlines within the URL
        guard !trimmed.contains(where: { $0.isWhitespace || $0.isNewline }) else { return nil }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return nil }
        guard scheme == "http" || scheme == "https" else { return nil }
        guard let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    /// If `urlString` is a valid HTTP/HTTPS URL and `selectedText` is not empty,
    /// returns `[selectedText](url)`. Otherwise returns `nil`.
    public static func linkWrapped(selectedText: String, urlString: String) -> String? {
        guard !selectedText.isEmpty else { return nil }
        guard let url = isHTTPURL(urlString) else { return nil }
        return "[\(selectedText)](\(url.absoluteString))"
    }

    /// Converts an HTML string into clean Markdown. Returns `nil` if the result is empty.
    public static func cleanMarkdown(fromHTML html: String) -> String? {
        let markdown = HTMLToMarkdown.convert(html)
        return markdown.isEmpty ? nil : markdown
    }

    #if canImport(AppKit)
    /// Converts RTF data into clean Markdown via AppKit's RTF reader.
    /// Returns `nil` if decoding fails or the result is empty.
    public static func cleanMarkdown(fromRTFData data: Data) -> String? {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]
        guard let attrString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        guard let htmlData = try? attrString.data(
            from: NSRange(location: 0, length: attrString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        ), let htmlString = String(data: htmlData, encoding: .utf8) else {
            return nil
        }
        return cleanMarkdown(fromHTML: htmlString)
    }
    #endif
}
