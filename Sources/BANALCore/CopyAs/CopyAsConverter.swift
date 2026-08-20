import AppKit
import Foundation

/// Fast, synchronous, in-memory converter for Edit → Copy As formats:
/// - Markdown (⌥⇧⌘C): copies raw plain text markdown (or selected snippet).
/// - Rich Text / RTF (⌥⌘C): renders formatted `public.rtf` with SF Pro typography, bold, italic, headings, lists, and code blocks.
/// - HTML: renders clean, semantic HTML markup and places it on the pasteboard as `public.html` + `public.utf8-plain-text`.
public enum CopyAsConverter {

    // MARK: - Public API

    /// Converts source text into a `CopyAsPayload` for the requested clipboard format.
    public static func convert(
        _ text: String,
        format: CopyAsFormat,
        language: NoteLanguage = .markdown,
        title: String? = nil,
        directory: URL? = nil
    ) -> CopyAsPayload {
        switch format {
        case .markdown:
            let plain = markdown(for: text, language: language)
            return CopyAsPayload(format: .markdown, plainText: plain)

        case .richText:
            let attributed = attributedString(for: text, language: language, title: title, directory: directory)
            let rtf = rtfData(for: text, language: language, title: title, directory: directory)
            return CopyAsPayload(format: .richText, plainText: attributed.string, rtfData: rtf)

        case .html:
            let htmlStr = html(for: text, language: language, title: title, directory: directory)
            let plain = attributedString(for: text, language: language, title: title, directory: directory).string
            return CopyAsPayload(format: .html, plainText: plain, html: htmlStr)
        }
    }

    /// Generates plain text Markdown representation.
    public static func markdown(for text: String, language: NoteLanguage = .markdown) -> String {
        guard let parsed = try? FrontmatterCodec.parse(text), parsed.hasFrontmatter else {
            return text
        }
        return parsed.body
    }

    /// Generates formatted `NSAttributedString` adhering to BANAL's quiet SF Pro typography.
    public static func attributedString(
        for text: String,
        language: NoteLanguage = .markdown,
        title: String? = nil,
        directory: URL? = nil
    ) -> NSAttributedString {
        switch language {
        case .markdown:
            return markdownAttributedString(for: text, fallbackTitle: title)
        case .textile:
            return textileAttributedString(for: text, fallbackTitle: title)
        case .cooklang:
            return cooklangAttributedString(for: text, fallbackTitle: title, directory: directory)
        }
    }

    /// Generates RTF data payload for rich text clipboard copying.
    public static func rtfData(
        for text: String,
        language: NoteLanguage = .markdown,
        title: String? = nil,
        directory: URL? = nil
    ) -> Data? {
        let attributed = attributedString(for: text, language: language, title: title, directory: directory)
        guard attributed.length > 0 else { return nil }
        let range = NSRange(location: 0, length: attributed.length)
        let docAttrs: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]
        return try? attributed.data(from: range, documentAttributes: docAttrs)
    }

    /// Generates clean, semantic HTML markup for HTML clipboard copying.
    public static func html(
        for text: String,
        language: NoteLanguage = .markdown,
        title: String? = nil,
        directory: URL? = nil
    ) -> String {
        switch language {
        case .markdown:
            return markdownHTML(for: text)
        case .textile:
            return textileHTML(for: text)
        case .cooklang:
            return cooklangHTML(for: text, fallbackTitle: title, directory: directory)
        }
    }

    /// Copies a `CopyAsPayload` to the specified pasteboard (defaults to `NSPasteboard.general`).
    @discardableResult
    public static func copy(
        _ payload: CopyAsPayload,
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        pasteboard.clearContents()
        switch payload.format {
        case .markdown:
            return pasteboard.setString(payload.plainText, forType: .string)

        case .richText:
            var success = false
            if let rtfData = payload.rtfData {
                success = pasteboard.setData(rtfData, forType: .rtf)
            }
            if !payload.plainText.isEmpty {
                pasteboard.setString(payload.plainText, forType: .string)
                success = true
            }
            return success

        case .html:
            var success = false
            if let html = payload.html {
                success = pasteboard.setString(html, forType: .html)
            }
            if !payload.plainText.isEmpty {
                pasteboard.setString(payload.plainText, forType: .string)
                success = true
            }
            return success
        }
    }

    /// Convenience: converts and copies text in one step.
    @discardableResult
    public static func copy(
        _ text: String,
        format: CopyAsFormat,
        language: NoteLanguage = .markdown,
        title: String? = nil,
        directory: URL? = nil,
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        let payload = convert(text, format: format, language: language, title: title, directory: directory)
        return copy(payload, to: pasteboard)
    }

    // MARK: - Rich Text Attributed String Formatting

    private static func markdownAttributedString(
        for source: String,
        fallbackTitle: String?
    ) -> NSAttributedString {
        let parsed = (try? FrontmatterCodec.parse(source)) ?? ParsedNoteDocument(hasFrontmatter: false, frontmatter: .empty, body: source, bodyOffset: 0)
        let body = parsed.body
        let result = NSMutableAttributedString()

        // If frontmatter is present with a title, render title and metadata at top
        if parsed.hasFrontmatter, let fmTitle = parsed.frontmatter.title ?? fallbackTitle {
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 4),
            ]
            result.append(NSAttributedString(string: fmTitle + "\n", attributes: titleAttrs))

            var metaParts: [String] = []
            if let created = parsed.frontmatter.created {
                metaParts.append(DayStamp.string(from: created))
            }
            if !parsed.frontmatter.tags.isEmpty {
                metaParts.append(parsed.frontmatter.tags.joined(separator: ", "))
            }
            if !metaParts.isEmpty {
                let metaAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 12),
                ]
                result.append(NSAttributedString(string: metaParts.joined(separator: " · ") + "\n", attributes: metaAttrs))
            }
        }

        let bodyLines = body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var inCodeFence = false
        var codeBuffer: [String] = []

        for (lineIdx, rawLine) in bodyLines.enumerated() {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code fences
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                if inCodeFence {
                    let codeText = codeBuffer.joined(separator: "\n")
                    codeBuffer.removeAll()
                    inCodeFence = false
                    let codeAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                        .foregroundColor: NSColor.labelColor,
                        .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.15),
                        .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 8),
                    ]
                    result.append(NSAttributedString(string: codeText + "\n", attributes: codeAttributes))
                } else {
                    inCodeFence = true
                }
                continue
            }

            if inCodeFence {
                codeBuffer.append(line)
                continue
            }

            if trimmed.isEmpty {
                // Don't append trailing empty spacing after the last line
                if lineIdx < bodyLines.count - 1 {
                    result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 6)]))
                }
                continue
            }

            // Headings
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix(while: { $0 == "#" })
                let level = hashes.count
                if level >= 1 && level <= 6 {
                    let text = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                    let font: NSFont
                    let spacingBefore: CGFloat
                    switch level {
                    case 1:
                        font = NSFont.systemFont(ofSize: 22, weight: .bold)
                        spacingBefore = (result.length == 0) ? 0 : 12
                    case 2:
                        font = NSFont.systemFont(ofSize: 18, weight: .semibold)
                        spacingBefore = (result.length == 0) ? 0 : 10
                    case 3:
                        font = NSFont.systemFont(ofSize: 16, weight: .semibold)
                        spacingBefore = (result.length == 0) ? 0 : 8
                    default:
                        font = NSFont.systemFont(ofSize: 14, weight: .semibold)
                        spacingBefore = (result.length == 0) ? 0 : 6
                    }
                    let headingStyle = paragraphStyle(lineSpacing: 2, paragraphSpacing: 4, paragraphSpacingBefore: spacingBefore)
                    let headingAttrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: NSColor.labelColor,
                        .paragraphStyle: headingStyle,
                    ]
                    let inlineFormatted = formatInlineMarkdown(text, baseFont: font)
                    let headingAttr = NSMutableAttributedString(attributedString: inlineFormatted)
                    headingAttr.addAttributes(headingAttrs, range: NSRange(location: 0, length: headingAttr.length))
                    headingAttr.append(NSAttributedString(string: "\n", attributes: headingAttrs))
                    result.append(headingAttr)
                    continue
                }
            }

            // Blockquote
            if trimmed.hasPrefix(">") {
                let quoteText = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                let quoteStyle = listParagraphStyle(indent: 16, paragraphSpacing: 6)
                let quoteAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: quoteStyle,
                ]
                let formatted = formatInlineMarkdown(quoteText, baseFont: NSFont.systemFont(ofSize: 14, weight: .regular))
                let quoteAttr = NSMutableAttributedString(string: "“\t", attributes: quoteAttrs)
                quoteAttr.append(formatted)
                quoteAttr.append(NSAttributedString(string: "”\n", attributes: quoteAttrs))
                result.append(quoteAttr)
                continue
            }

            // Unordered list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                let listStyle = listParagraphStyle(indent: 16, paragraphSpacing: 4)
                let itemAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: listStyle,
                ]
                let formattedInline = formatInlineMarkdown(itemText, baseFont: NSFont.systemFont(ofSize: 14, weight: .regular))
                let bulletAttr = NSMutableAttributedString(string: "•\t", attributes: itemAttrs)
                bulletAttr.append(formattedInline)
                bulletAttr.append(NSAttributedString(string: "\n", attributes: itemAttrs))
                result.append(bulletAttr)
                continue
            }

            // Numbered list
            if let dotIndex = trimmed.firstIndex(of: "."),
               let _ = Int(trimmed[..<dotIndex]) {
                let prefix = String(trimmed[...dotIndex])
                let itemText = String(trimmed[trimmed.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
                let numStyle = listParagraphStyle(indent: 24, paragraphSpacing: 4)
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: numStyle,
                ]
                let formattedInline = formatInlineMarkdown(itemText, baseFont: NSFont.systemFont(ofSize: 14, weight: .regular))
                let numPrefixAttr = NSMutableAttributedString(string: "\(prefix)\t", attributes: numAttrs)
                numPrefixAttr.append(formattedInline)
                numPrefixAttr.append(NSAttributedString(string: "\n", attributes: numAttrs))
                result.append(numPrefixAttr)
                continue
            }

            // Regular paragraph
            let bodyStyle = paragraphStyle(lineSpacing: 3, paragraphSpacing: 8)
            let formattedParagraph = formatInlineMarkdown(line, baseFont: NSFont.systemFont(ofSize: 14, weight: .regular))
            let pAttr = NSMutableAttributedString(attributedString: formattedParagraph)
            pAttr.addAttributes([.paragraphStyle: bodyStyle], range: NSRange(location: 0, length: pAttr.length))
            pAttr.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: bodyStyle]))
            result.append(pAttr)
        }

        if inCodeFence && !codeBuffer.isEmpty {
            let codeText = codeBuffer.joined(separator: "\n")
            let codeAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.15),
                .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 8),
            ]
            result.append(NSAttributedString(string: codeText + "\n", attributes: codeAttributes))
        }

        return result
    }

    private static func textileAttributedString(
        for source: String,
        fallbackTitle: String?
    ) -> NSAttributedString {
        let parsed = (try? FrontmatterCodec.parse(source)) ?? ParsedNoteDocument(hasFrontmatter: false, frontmatter: .empty, body: source, bodyOffset: 0)
        let body = parsed.body
        let result = NSMutableAttributedString()

        let bodyLines = body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var inBlockCode = false
        var codeBuffer: [String] = []

        for rawLine in bodyLines {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("bc. ") || trimmed == "bc." {
                inBlockCode = true
                let codePart = trimmed.hasPrefix("bc. ") ? String(trimmed.dropFirst(4)) : ""
                if !codePart.isEmpty { codeBuffer.append(codePart) }
                continue
            }

            if inBlockCode {
                if trimmed.isEmpty {
                    let codeText = codeBuffer.joined(separator: "\n")
                    codeBuffer.removeAll()
                    inBlockCode = false
                    let codeAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                        .foregroundColor: NSColor.labelColor,
                        .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.15),
                        .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 8),
                    ]
                    result.append(NSAttributedString(string: codeText + "\n\n", attributes: codeAttributes))
                } else {
                    codeBuffer.append(line)
                }
                continue
            }

            if trimmed.isEmpty {
                result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 6)]))
                continue
            }

            // Headings h1. through h6.
            if trimmed.count >= 4 && trimmed.hasPrefix("h") && trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)...].hasPrefix(". ") {
                let digitChar = trimmed[trimmed.index(after: trimmed.startIndex)]
                if let level = Int(String(digitChar)), level >= 1 && level <= 6 {
                    let text = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                    let font: NSFont
                    let spacingBefore: CGFloat
                    switch level {
                    case 1:
                        font = NSFont.systemFont(ofSize: 22, weight: .bold)
                        spacingBefore = (result.length == 0) ? 0 : 12
                    case 2:
                        font = NSFont.systemFont(ofSize: 18, weight: .semibold)
                        spacingBefore = (result.length == 0) ? 0 : 10
                    case 3:
                        font = NSFont.systemFont(ofSize: 16, weight: .semibold)
                        spacingBefore = (result.length == 0) ? 0 : 8
                    default:
                        font = NSFont.systemFont(ofSize: 14, weight: .semibold)
                        spacingBefore = (result.length == 0) ? 0 : 6
                    }
                    let headingStyle = paragraphStyle(lineSpacing: 2, paragraphSpacing: 4, paragraphSpacingBefore: spacingBefore)
                    let headingAttrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: NSColor.labelColor,
                        .paragraphStyle: headingStyle,
                    ]
                    result.append(NSAttributedString(string: text + "\n", attributes: headingAttrs))
                    continue
                }
            }

            // Bullet list
            if trimmed.hasPrefix("* ") {
                let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                let listStyle = listParagraphStyle(indent: 16, paragraphSpacing: 4)
                let itemAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: listStyle,
                ]
                let formattedInline = formatInlineTextile(itemText, baseFont: NSFont.systemFont(ofSize: 14, weight: .regular))
                let bulletAttr = NSMutableAttributedString(string: "•\t", attributes: itemAttrs)
                bulletAttr.append(formattedInline)
                bulletAttr.append(NSAttributedString(string: "\n", attributes: itemAttrs))
                result.append(bulletAttr)
                continue
            }

            // Numbered list
            if trimmed.hasPrefix("# ") {
                let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                let numStyle = listParagraphStyle(indent: 20, paragraphSpacing: 4)
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: numStyle,
                ]
                let formattedInline = formatInlineTextile(itemText, baseFont: NSFont.systemFont(ofSize: 14, weight: .regular))
                let numPrefixAttr = NSMutableAttributedString(string: "—\t", attributes: numAttrs)
                numPrefixAttr.append(formattedInline)
                numPrefixAttr.append(NSAttributedString(string: "\n", attributes: numAttrs))
                result.append(numPrefixAttr)
                continue
            }

            // Paragraph
            var pText = line
            if trimmed.hasPrefix("p. ") {
                pText = String(trimmed.dropFirst(3))
            }
            let bodyStyle = paragraphStyle(lineSpacing: 3, paragraphSpacing: 8)
            let formattedParagraph = formatInlineTextile(pText, baseFont: NSFont.systemFont(ofSize: 14, weight: .regular))
            let pAttr = NSMutableAttributedString(attributedString: formattedParagraph)
            pAttr.addAttributes([.paragraphStyle: bodyStyle], range: NSRange(location: 0, length: pAttr.length))
            pAttr.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: bodyStyle]))
            result.append(pAttr)
        }

        return result
    }

    private static func cooklangAttributedString(
        for source: String,
        fallbackTitle: String?,
        directory: URL?
    ) -> NSAttributedString {
        return NotePreviewGenerator.attributedPreview(for: source, language: .cooklang, fallbackTitle: fallbackTitle, directory: directory)
    }

    // MARK: - Inline Formatting Helpers for Rich Text

    private static func formatInlineMarkdown(_ text: String, baseFont: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
        ])

        let boldFont = NSFont.systemFont(ofSize: baseFont.pointSize, weight: .bold)
        let italicDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.italic)
        let italicFont = NSFont(descriptor: italicDescriptor, size: baseFont.pointSize) ?? baseFont
        let monoFont = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)

        applyLinks(in: result)
        applyRegex(pattern: "\\*\\*(.*?)\\*\\*", in: result, font: boldFont)
        applyRegex(pattern: "__(.*?)__", in: result, font: boldFont)
        applyRegex(pattern: "(?<!\\*)\\*(?!\\*)(.*?)(?<!\\*)\\*(?!\\*)", in: result, font: italicFont)
        applyRegex(pattern: "(?<!_)_(?!_)(.*?)(?<!_)_(?!_)", in: result, font: italicFont)
        applyRegex(pattern: "~~(.*?)~~", in: result, strikethrough: true)
        applyRegex(pattern: "`(.*?)`", in: result, font: monoFont, color: NSColor.secondaryLabelColor)

        return result
    }

    private static func formatInlineTextile(_ text: String, baseFont: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
        ])

        let boldFont = NSFont.systemFont(ofSize: baseFont.pointSize, weight: .bold)
        let italicDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.italic)
        let italicFont = NSFont(descriptor: italicDescriptor, size: baseFont.pointSize) ?? baseFont
        let monoFont = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)

        applyRegex(pattern: "\\*(.*?)\\*", in: result, font: boldFont)
        applyRegex(pattern: "_(.*?)_", in: result, font: italicFont)
        applyRegex(pattern: "@(.*?)@", in: result, font: monoFont, color: NSColor.secondaryLabelColor)
        applyRegex(pattern: "-(.*?)-", in: result, strikethrough: true)

        return result
    }

    private static func applyLinks(in attrString: NSMutableAttributedString) {
        guard let regex = try? NSRegularExpression(pattern: #"(?<!!)\[(.*?)\]\((.*?)\)"#, options: []) else { return }
        let matches = regex.matches(in: attrString.string, options: [], range: NSRange(location: 0, length: attrString.length))

        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }
            let fullRange = match.range(at: 0)
            let textRange = match.range(at: 1)
            let urlRange = match.range(at: 2)

            guard textRange.location != NSNotFound, urlRange.location != NSNotFound else { continue }
            let urlString = (attrString.string as NSString).substring(with: urlRange).trimmingCharacters(in: .whitespacesAndNewlines)
            let innerAttr = attrString.attributedSubstring(from: textRange).mutableCopy() as! NSMutableAttributedString
            let linkRange = NSRange(location: 0, length: innerAttr.length)
            if let url = URL(string: urlString) {
                innerAttr.addAttribute(.link, value: url, range: linkRange)
            } else {
                innerAttr.addAttribute(.link, value: urlString, range: linkRange)
            }
            innerAttr.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: linkRange)
            innerAttr.addAttribute(.foregroundColor, value: NSColor.linkColor, range: linkRange)
            attrString.replaceCharacters(in: fullRange, with: innerAttr)
        }
    }

    private static func applyRegex(
        pattern: String,
        in attrString: NSMutableAttributedString,
        font: NSFont? = nil,
        color: NSColor? = nil,
        strikethrough: Bool = false
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let matches = regex.matches(in: attrString.string, options: [], range: NSRange(location: 0, length: attrString.length))

        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else { continue }
            let fullRange = match.range(at: 0)
            let innerRange = match.range(at: 1)

            guard innerRange.location != NSNotFound, innerRange.length > 0 else { continue }
            let innerAttr = attrString.attributedSubstring(from: innerRange).mutableCopy() as! NSMutableAttributedString
            let targetRange = NSRange(location: 0, length: innerAttr.length)

            if let font {
                innerAttr.addAttribute(.font, value: font, range: targetRange)
            }
            if let color {
                innerAttr.addAttribute(.foregroundColor, value: color, range: targetRange)
            }
            if strikethrough {
                innerAttr.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: targetRange)
            }

            attrString.replaceCharacters(in: fullRange, with: innerAttr)
        }
    }

    private static func paragraphStyle(
        lineSpacing: CGFloat,
        paragraphSpacing: CGFloat,
        paragraphSpacingBefore: CGFloat = 0
    ) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = paragraphSpacing
        style.paragraphSpacingBefore = paragraphSpacingBefore
        return style
    }

    private static func listParagraphStyle(
        indent: CGFloat,
        paragraphSpacing: CGFloat
    ) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.headIndent = indent
        style.firstLineHeadIndent = 0
        style.paragraphSpacing = paragraphSpacing
        style.tabStops = [NSTextTab(textAlignment: .left, location: indent, options: [:])]
        return style
    }

    // MARK: - HTML Rendering

    private static func markdownHTML(for source: String) -> String {
        let parsed = (try? FrontmatterCodec.parse(source)) ?? ParsedNoteDocument(hasFrontmatter: false, frontmatter: .empty, body: source, bodyOffset: 0)
        let body = parsed.body

        var html = ""
        let lines = body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

        var inCodeFence = false
        var codeBuffer: [String] = []
        var listKind: ListKind? = nil
        var listItems: [String] = []
        var quoteLines: [String] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            let text = paragraphLines.joined(separator: "\n")
            paragraphLines.removeAll()
            let formatted = formatInlineMarkdownHTML(text)
            if !formatted.isEmpty {
                html += "<p>\(formatted)</p>\n"
            }
        }

        func flushList() {
            guard let kind = listKind, !listItems.isEmpty else { return }
            let tag = kind == .ordered ? "ol" : "ul"
            html += "<\(tag)>\n"
            for item in listItems {
                let formatted = formatInlineMarkdownHTML(item)
                html += "  <li>\(formatted)</li>\n"
            }
            html += "</\(tag)>\n"
            listKind = nil
            listItems.removeAll()
        }

        func flushBlockquote() {
            guard !quoteLines.isEmpty else { return }
            let text = quoteLines.joined(separator: "\n")
            quoteLines.removeAll()
            let formatted = formatInlineMarkdownHTML(text)
            html += "<blockquote><p>\(formatted)</p></blockquote>\n"
        }

        for rawLine in lines {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code fences
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flushParagraph()
                flushList()
                flushBlockquote()

                if inCodeFence {
                    let codeText = codeBuffer.joined(separator: "\n")
                    codeBuffer.removeAll()
                    inCodeFence = false
                    html += "<pre><code>\(escapeHTML(codeText))</code></pre>\n"
                } else {
                    inCodeFence = true
                }
                continue
            }

            if inCodeFence {
                codeBuffer.append(line)
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                flushList()
                flushBlockquote()
                continue
            }

            // Headings
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix(while: { $0 == "#" })
                let level = min(6, hashes.count)
                if level >= 1 && level <= 6 {
                    flushParagraph()
                    flushList()
                    flushBlockquote()
                    let headingText = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                    let formatted = formatInlineMarkdownHTML(headingText)
                    html += "<h\(level)>\(formatted)</h\(level)>\n"
                    continue
                }
            }

            // Blockquotes
            if trimmed.hasPrefix(">") {
                flushParagraph()
                flushList()
                let quoteText = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                quoteLines.append(quoteText)
                continue
            } else if !quoteLines.isEmpty {
                flushBlockquote()
            }

            // Unordered list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                flushParagraph()
                flushBlockquote()
                if listKind != .unordered {
                    flushList()
                    listKind = .unordered
                }
                let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                listItems.append(itemText)
                continue
            }

            // Ordered list
            if let dotIndex = trimmed.firstIndex(of: "."),
               let _ = Int(trimmed[..<dotIndex]) {
                flushParagraph()
                flushBlockquote()
                if listKind != .ordered {
                    flushList()
                    listKind = .ordered
                }
                let itemText = String(trimmed[trimmed.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
                listItems.append(itemText)
                continue
            }

            // Horizontal rules
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                flushList()
                flushBlockquote()
                html += "<hr>\n"
                continue
            }

            // Regular paragraph line
            flushList()
            flushBlockquote()
            paragraphLines.append(line)
        }

        flushParagraph()
        flushList()
        flushBlockquote()

        if inCodeFence && !codeBuffer.isEmpty {
            let codeText = codeBuffer.joined(separator: "\n")
            html += "<pre><code>\(escapeHTML(codeText))</code></pre>\n"
        }

        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum ListKind {
        case unordered
        case ordered
    }

    private static func textileHTML(for source: String) -> String {
        let parsed = (try? FrontmatterCodec.parse(source)) ?? ParsedNoteDocument(hasFrontmatter: false, frontmatter: .empty, body: source, bodyOffset: 0)
        let body = parsed.body

        var html = ""
        let lines = body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

        var inBlockCode = false
        var codeBuffer: [String] = []
        var listKind: ListKind? = nil
        var listItems: [String] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            let text = paragraphLines.joined(separator: "\n")
            paragraphLines.removeAll()
            let formatted = formatInlineTextileHTML(text)
            if !formatted.isEmpty {
                html += "<p>\(formatted)</p>\n"
            }
        }

        func flushList() {
            guard let kind = listKind, !listItems.isEmpty else { return }
            let tag = kind == .ordered ? "ol" : "ul"
            html += "<\(tag)>\n"
            for item in listItems {
                let formatted = formatInlineTextileHTML(item)
                html += "  <li>\(formatted)</li>\n"
            }
            html += "</\(tag)>\n"
            listKind = nil
            listItems.removeAll()
        }

        for rawLine in lines {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("bc. ") || trimmed == "bc." {
                flushParagraph()
                flushList()
                inBlockCode = true
                let codePart = trimmed.hasPrefix("bc. ") ? String(trimmed.dropFirst(4)) : ""
                if !codePart.isEmpty { codeBuffer.append(codePart) }
                continue
            }

            if inBlockCode {
                if trimmed.isEmpty {
                    let codeText = codeBuffer.joined(separator: "\n")
                    codeBuffer.removeAll()
                    inBlockCode = false
                    html += "<pre><code>\(escapeHTML(codeText))</code></pre>\n"
                } else {
                    codeBuffer.append(line)
                }
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                flushList()
                continue
            }

            // Headings h1. through h6.
            if trimmed.count >= 4 && trimmed.hasPrefix("h") && trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)...].hasPrefix(". ") {
                let digitChar = trimmed[trimmed.index(after: trimmed.startIndex)]
                if let level = Int(String(digitChar)), level >= 1 && level <= 6 {
                    flushParagraph()
                    flushList()
                    let text = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                    let formatted = formatInlineTextileHTML(text)
                    html += "<h\(level)>\(formatted)</h\(level)>\n"
                    continue
                }
            }

            // Bullet list
            if trimmed.hasPrefix("* ") {
                flushParagraph()
                if listKind != .unordered {
                    flushList()
                    listKind = .unordered
                }
                let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                listItems.append(itemText)
                continue
            }

            // Numbered list
            if trimmed.hasPrefix("# ") {
                flushParagraph()
                if listKind != .ordered {
                    flushList()
                    listKind = .ordered
                }
                let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                listItems.append(itemText)
                continue
            }

            // Paragraph
            var pText = line
            if trimmed.hasPrefix("p. ") {
                pText = String(trimmed.dropFirst(3))
            }
            paragraphLines.append(pText)
        }

        flushParagraph()
        flushList()

        if inBlockCode && !codeBuffer.isEmpty {
            let codeText = codeBuffer.joined(separator: "\n")
            html += "<pre><code>\(escapeHTML(codeText))</code></pre>\n"
        }

        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cooklangHTML(
        for source: String,
        fallbackTitle: String?,
        directory: URL?
    ) -> String {
        let model = NotePreviewGenerator.recipePreview(for: source, fallbackTitle: fallbackTitle, directory: directory)
        var html = ""

        if !model.title.isEmpty {
            html += "<h1>\(escapeHTML(model.title))</h1>\n"
        }

        if !model.ingredients.isEmpty {
            html += "<h2>Ingredients</h2>\n<ul>\n"
            for ing in model.ingredients {
                html += "  <li>\(escapeHTML(ing.displayString))</li>\n"
            }
            html += "</ul>\n"
        }

        if !model.cookware.isEmpty {
            html += "<h2>Cookware</h2>\n<ul>\n"
            for cw in model.cookware {
                html += "  <li>\(escapeHTML(cw))</li>\n"
            }
            html += "</ul>\n"
        }

        if !model.steps.isEmpty {
            html += "<h2>Instructions</h2>\n<ol>\n"
            for step in model.steps {
                html += "  <li>\(escapeHTML(step))</li>\n"
            }
            html += "</ol>\n"
        }

        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - HTML Inline Formatting & Escaping

    private static func formatInlineMarkdownHTML(_ text: String) -> String {
        var str = escapeHTML(text)

        // Images: ![alt](url) -> <img src="url" alt="alt">
        str = replacePattern(#"!\[(.*?)\]\((.*?)\)"#, in: str, with: #"<img src="$2" alt="$1">"#)

        // Links: [text](url) -> <a href="url">text</a>
        str = replacePattern(#"(?<!!)\[(.*?)\]\((.*?)\)"#, in: str, with: #"<a href="$2">$1</a>"#)

        // Bold: **text** or __text__ -> <strong>text</strong>
        str = replacePattern(#"\*\*(.*?)\*\*"#, in: str, with: "<strong>$1</strong>")
        str = replacePattern(#"__(.*?)__"#, in: str, with: "<strong>$1</strong>")

        // Italic: *text* or _text_ -> <em>text</em>
        str = replacePattern(#"(?<!\*)\*(?!\*)(.*?)(?<!\*)\*(?!\*)"#, in: str, with: "<em>$1</em>")
        str = replacePattern(#"(?<!_)_(?!_)(.*?)(?<!_)_(?!_)"#, in: str, with: "<em>$1</em>")

        // Strikethrough: ~~text~~ -> <del>text</del>
        str = replacePattern(#"~~(.*?)~~"#, in: str, with: "<del>$1</del>")

        // Code: `code` -> <code>code</code>
        str = replacePattern(#"`(.*?)`"#, in: str, with: "<code>$1</code>")

        return str
    }

    private static func formatInlineTextileHTML(_ text: String) -> String {
        var str = escapeHTML(text)

        // Bold: *text* -> <strong>text</strong>
        str = replacePattern(#"\*(.*?)\*"#, in: str, with: "<strong>$1</strong>")

        // Italic: _text_ -> <em>text</em>
        str = replacePattern(#"_(.*?)_"#, in: str, with: "<em>$1</em>")

        // Strikethrough: -text- -> <del>text</del>
        str = replacePattern(#"-(.*?)-"#, in: str, with: "<del>$1</del>")

        // Code: @code@ -> <code>code</code>
        str = replacePattern(#"@(.*?)@"#, in: str, with: "<code>$1</code>")

        // Links: "text":url -> <a href="url">text</a>
        str = replacePattern(#"\"(.*?)\":(https?:\/\/\S+)"#, in: str, with: #"<a href="$2">$1</a>"#)

        return str
    }

    private static func replacePattern(_ pattern: String, in text: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }

    private static func escapeHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }
}
