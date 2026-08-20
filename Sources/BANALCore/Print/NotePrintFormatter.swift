import AppKit
import Foundation

/// Formats BANAL notes and recipes into clean, high-contrast, printable `NSAttributedString`
/// documents adhering to SF Pro typography.
///
/// Supports Edit mode (formatted source representation) and Recipe Read mode
/// (title, scale, metadata, ingredient list, cookware, and numbered instructions).
public enum NotePrintFormatter {

    // MARK: - Public API

    /// Generate an `NSAttributedString` suitable for pagination and printing for a `Note`.
    public static func attributedString(
        for note: Note,
        isRecipeReadMode: Bool = false,
        recipeModel: NotePreviewGenerator.RecipePreviewModel? = nil,
        scaleLabel: String? = nil
    ) -> NSAttributedString {
        attributedString(
            for: note.body,
            language: note.language,
            isRecipeReadMode: isRecipeReadMode,
            fallbackTitle: note.displayTitle,
            directory: note.fileURL.deletingLastPathComponent(),
            created: note.created,
            tags: note.tags,
            recipeModel: recipeModel,
            scaleLabel: scaleLabel
        )
    }

    /// Generate an `NSAttributedString` suitable for pagination and printing for raw content.
    public static func attributedString(
        for source: String,
        language: NoteLanguage,
        isRecipeReadMode: Bool = false,
        fallbackTitle: String? = nil,
        directory: URL? = nil,
        created: Date? = nil,
        tags: [String] = [],
        recipeModel: NotePreviewGenerator.RecipePreviewModel? = nil,
        scaleLabel: String? = nil
    ) -> NSAttributedString {
        if isRecipeReadMode || language == .cooklang {
            let model = recipeModel ?? NotePreviewGenerator.recipePreview(for: source, fallbackTitle: fallbackTitle, directory: directory)
            return recipePrintAttributedString(model: model, scaleLabel: scaleLabel)
        }

        switch language {
        case .markdown:
            return markdownPrintAttributedString(source: source, fallbackTitle: fallbackTitle, created: created, tags: tags)
        case .textile:
            return textilePrintAttributedString(source: source, fallbackTitle: fallbackTitle, created: created, tags: tags)
        case .cooklang:
            let model = recipeModel ?? NotePreviewGenerator.recipePreview(for: source, fallbackTitle: fallbackTitle, directory: directory)
            return recipePrintAttributedString(model: model, scaleLabel: scaleLabel)
        }
    }

    // MARK: - Recipe Printing

    private static func recipePrintAttributedString(
        model: NotePreviewGenerator.RecipePreviewModel,
        scaleLabel: String?
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Title (20pt Bold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 4),
        ]
        result.append(NSAttributedString(string: model.title + "\n", attributes: titleAttributes))

        // Metadata items (Scale, Servings, Cook Time, Tags)
        var metaItems: [String] = []
        if let scaleLabel, !scaleLabel.isEmpty && scaleLabel != "1×" {
            metaItems.append("Scale: \(scaleLabel)")
        }
        if let servings = model.metadata["servings"] {
            metaItems.append("Servings: \(servings)")
        }
        if let time = model.metadata["time"] ?? model.metadata["cook time"] {
            metaItems.append("Time: \(time)")
        }
        let allTags = Array(Set(model.tags)).sorted()
        if !allTags.isEmpty {
            metaItems.append(allTags.joined(separator: ", "))
        }

        if !metaItems.isEmpty {
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 14),
            ]
            result.append(NSAttributedString(string: metaItems.joined(separator: " · ") + "\n", attributes: metaAttributes))
        } else {
            result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 6)]))
        }

        // Section: Ingredients
        if !model.ingredients.isEmpty {
            let sectionAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 6, paragraphSpacingBefore: 8),
            ]
            result.append(NSAttributedString(string: "Ingredients\n", attributes: sectionAttributes))

            let itemAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: listParagraphStyle(indent: 14, paragraphSpacing: 3),
            ]

            for ing in model.ingredients {
                let line = "•\t\(ing.displayString)\n"
                result.append(NSAttributedString(string: line, attributes: itemAttributes))
            }
            result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 6)]))
        }

        // Section: Cookware
        if !model.cookware.isEmpty {
            let sectionAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 6, paragraphSpacingBefore: 8),
            ]
            result.append(NSAttributedString(string: "Cookware\n", attributes: sectionAttributes))

            let itemAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: listParagraphStyle(indent: 14, paragraphSpacing: 3),
            ]

            for cw in model.cookware {
                let line = "•\t\(cw)\n"
                result.append(NSAttributedString(string: line, attributes: itemAttributes))
            }
            result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 6)]))
        }

        // Section: Instructions / Method
        if !model.steps.isEmpty {
            let sectionAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 6, paragraphSpacingBefore: 8),
            ]
            result.append(NSAttributedString(string: "Instructions\n", attributes: sectionAttributes))

            let stepAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: listParagraphStyle(indent: 20, paragraphSpacing: 6),
            ]

            for (idx, step) in model.steps.enumerated() {
                let stepStr = "\(idx + 1).\t\(step)\n"
                result.append(NSAttributedString(string: stepStr, attributes: stepAttributes))
            }
        }

        return result
    }

    // MARK: - Markdown Printing

    private static func markdownPrintAttributedString(
        source: String,
        fallbackTitle: String?,
        created: Date?,
        tags: [String]
    ) -> NSAttributedString {
        let parsed = (try? FrontmatterCodec.parse(source)) ?? ParsedNoteDocument(hasFrontmatter: false, frontmatter: .empty, body: source, bodyOffset: 0)
        let title = parsed.frontmatter.title ?? inferredTitle(from: parsed.body) ?? fallbackTitle ?? "Untitled"
        let mergedTags = Array(Set(parsed.frontmatter.tags + tags)).sorted()
        let noteCreated = parsed.frontmatter.created ?? created

        let result = NSMutableAttributedString()

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 4),
        ]
        result.append(NSAttributedString(string: title + "\n", attributes: titleAttributes))

        // Metadata
        var metaParts: [String] = []
        if let noteCreated {
            metaParts.append(DayStamp.string(from: noteCreated))
        }
        if !mergedTags.isEmpty {
            metaParts.append(mergedTags.joined(separator: ", "))
        }

        if !metaParts.isEmpty {
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 14),
            ]
            result.append(NSAttributedString(string: metaParts.joined(separator: " · ") + "\n", attributes: metaAttributes))
        } else {
            result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 6)]))
        }

        // Body lines
        let bodyLines = parsed.body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var inCodeFence = false
        var codeBuffer: [String] = []
        var skippedFirstHeading = (parsed.frontmatter.title == nil)

        for rawLine in bodyLines {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                if inCodeFence {
                    let codeText = codeBuffer.joined(separator: "\n")
                    codeBuffer.removeAll()
                    inCodeFence = false
                    let codeAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                        .foregroundColor: NSColor.labelColor,
                        .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.12),
                        .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 6),
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
                result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 5)]))
                continue
            }

            // Headings
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix(while: { $0 == "#" })
                let level = hashes.count
                if level >= 1 && level <= 6 {
                    let text = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                    if skippedFirstHeading && level == 1 && text == title {
                        skippedFirstHeading = false
                        continue
                    }
                    let font: NSFont
                    let spacingBefore: CGFloat
                    switch level {
                    case 1:
                        font = NSFont.systemFont(ofSize: 16, weight: .bold)
                        spacingBefore = 10
                    case 2:
                        font = NSFont.systemFont(ofSize: 14, weight: .semibold)
                        spacingBefore = 8
                    case 3:
                        font = NSFont.systemFont(ofSize: 12, weight: .semibold)
                        spacingBefore = 6
                    default:
                        font = NSFont.systemFont(ofSize: 11, weight: .semibold)
                        spacingBefore = 5
                    }
                    let headingAttrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: NSColor.labelColor,
                        .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 3, paragraphSpacingBefore: spacingBefore),
                    ]
                    result.append(NSAttributedString(string: text + "\n", attributes: headingAttrs))
                    continue
                }
            }

            // Blockquote
            if trimmed.hasPrefix(">") {
                let quoteText = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                let quoteStyle = listParagraphStyle(indent: 14, paragraphSpacing: 4)
                let quoteAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: quoteStyle,
                ]
                result.append(NSAttributedString(string: "“\t\(quoteText)”\n", attributes: quoteAttrs))
                continue
            }

            // Unordered list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                let listStyle = listParagraphStyle(indent: 14, paragraphSpacing: 3)
                let itemAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: listStyle,
                ]
                let formattedInline = formatInlineText(itemText, baseFontSize: 11)
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
                let numStyle = listParagraphStyle(indent: 18, paragraphSpacing: 3)
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: numStyle,
                ]
                let formattedInline = formatInlineText(itemText, baseFontSize: 11)
                let numPrefixAttr = NSMutableAttributedString(string: "\(prefix)\t", attributes: numAttrs)
                numPrefixAttr.append(formattedInline)
                numPrefixAttr.append(NSAttributedString(string: "\n", attributes: numAttrs))
                result.append(numPrefixAttr)
                continue
            }

            // Regular paragraph
            let bodyStyle = paragraphStyle(lineSpacing: 2, paragraphSpacing: 6)
            let formattedParagraph = formatInlineText(line, baseFontSize: 11)
            let pAttr = NSMutableAttributedString(attributedString: formattedParagraph)
            pAttr.addAttributes([.paragraphStyle: bodyStyle], range: NSRange(location: 0, length: pAttr.length))
            pAttr.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: bodyStyle]))
            result.append(pAttr)
        }

        if inCodeFence && !codeBuffer.isEmpty {
            let codeText = codeBuffer.joined(separator: "\n")
            let codeAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.12),
                .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 6),
            ]
            result.append(NSAttributedString(string: codeText + "\n", attributes: codeAttributes))
        }

        return result
    }

    // MARK: - Textile Printing

    private static func textilePrintAttributedString(
        source: String,
        fallbackTitle: String?,
        created: Date?,
        tags: [String]
    ) -> NSAttributedString {
        let parsed = (try? FrontmatterCodec.parse(source)) ?? ParsedNoteDocument(hasFrontmatter: false, frontmatter: .empty, body: source, bodyOffset: 0)
        let title = parsed.frontmatter.title ?? inferredTitle(from: parsed.body) ?? fallbackTitle ?? "Untitled"
        let mergedTags = Array(Set(parsed.frontmatter.tags + tags)).sorted()
        let noteCreated = parsed.frontmatter.created ?? created

        let result = NSMutableAttributedString()

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 4),
        ]
        result.append(NSAttributedString(string: title + "\n", attributes: titleAttributes))

        // Metadata
        var metaParts: [String] = []
        if let noteCreated {
            metaParts.append(DayStamp.string(from: noteCreated))
        }
        if !mergedTags.isEmpty {
            metaParts.append(mergedTags.joined(separator: ", "))
        }

        if !metaParts.isEmpty {
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 14),
            ]
            result.append(NSAttributedString(string: metaParts.joined(separator: " · ") + "\n", attributes: metaAttributes))
        } else {
            result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 6)]))
        }

        let bodyLines = parsed.body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var inBlockCode = false
        var codeBuffer: [String] = []
        var skippedFirstHeading = (parsed.frontmatter.title == nil)

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
                        .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                        .foregroundColor: NSColor.labelColor,
                        .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.12),
                        .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 6),
                    ]
                    result.append(NSAttributedString(string: codeText + "\n\n", attributes: codeAttributes))
                } else {
                    codeBuffer.append(line)
                }
                continue
            }

            if trimmed.isEmpty {
                result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 5)]))
                continue
            }

            // Headings h1. through h6.
            if trimmed.count >= 4 && trimmed.hasPrefix("h") && trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)...].hasPrefix(". ") {
                let digitChar = trimmed[trimmed.index(after: trimmed.startIndex)]
                if let level = Int(String(digitChar)), level >= 1 && level <= 6 {
                    let text = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                    if skippedFirstHeading && level == 1 && text == title {
                        skippedFirstHeading = false
                        continue
                    }
                    let font: NSFont
                    let spacingBefore: CGFloat
                    switch level {
                    case 1:
                        font = NSFont.systemFont(ofSize: 16, weight: .bold)
                        spacingBefore = 10
                    case 2:
                        font = NSFont.systemFont(ofSize: 14, weight: .semibold)
                        spacingBefore = 8
                    case 3:
                        font = NSFont.systemFont(ofSize: 12, weight: .semibold)
                        spacingBefore = 6
                    default:
                        font = NSFont.systemFont(ofSize: 11, weight: .semibold)
                        spacingBefore = 5
                    }
                    let headingAttrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: NSColor.labelColor,
                        .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 3, paragraphSpacingBefore: spacingBefore),
                    ]
                    result.append(NSAttributedString(string: text + "\n", attributes: headingAttrs))
                    continue
                }
            }

            // Bullet list
            if trimmed.hasPrefix("* ") {
                let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                let listStyle = listParagraphStyle(indent: 14, paragraphSpacing: 3)
                let itemAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: listStyle,
                ]
                let formattedInline = formatInlineText(itemText, baseFontSize: 11)
                let bulletAttr = NSMutableAttributedString(string: "•\t", attributes: itemAttrs)
                bulletAttr.append(formattedInline)
                bulletAttr.append(NSAttributedString(string: "\n", attributes: itemAttrs))
                result.append(bulletAttr)
                continue
            }

            // Numbered list
            if trimmed.hasPrefix("# ") {
                let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                let numStyle = listParagraphStyle(indent: 18, paragraphSpacing: 3)
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: numStyle,
                ]
                let formattedInline = formatInlineText(itemText, baseFontSize: 11)
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
            let bodyStyle = paragraphStyle(lineSpacing: 2, paragraphSpacing: 6)
            let formattedParagraph = formatInlineText(pText, baseFontSize: 11)
            let pAttr = NSMutableAttributedString(attributedString: formattedParagraph)
            pAttr.addAttributes([.paragraphStyle: bodyStyle], range: NSRange(location: 0, length: pAttr.length))
            pAttr.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: bodyStyle]))
            result.append(pAttr)
        }

        if inBlockCode && !codeBuffer.isEmpty {
            let codeText = codeBuffer.joined(separator: "\n")
            let codeAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.12),
                .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 6),
            ]
            result.append(NSAttributedString(string: codeText + "\n\n", attributes: codeAttributes))
        }

        return result
    }

    // MARK: - Helpers

    private static func formatInlineText(_ text: String, baseFontSize: CGFloat) -> NSAttributedString {
        let baseFont = NSFont.systemFont(ofSize: baseFontSize, weight: .regular)
        let boldFont = NSFont.systemFont(ofSize: baseFontSize, weight: .bold)
        let italicDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.italic)
        let italicFont = NSFont(descriptor: italicDescriptor, size: baseFontSize) ?? baseFont
        let monoFont = NSFont.monospacedSystemFont(ofSize: baseFontSize - 1, weight: .regular)

        let result = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
        ])

        applyRegex(pattern: "\\*\\*(.*?)\\*\\*", in: result, font: boldFont, stripDelimiterLength: 2)
        applyRegex(pattern: "__(.*?)__", in: result, font: boldFont, stripDelimiterLength: 2)
        applyRegex(pattern: "(?<!\\*)\\*(?!\\*)(.*?)(?<!\\*)\\*(?!\\*)", in: result, font: italicFont, stripDelimiterLength: 1)
        applyRegex(pattern: "(?<!_)_(?!_)(.*?)(?<!_)_(?!_)", in: result, font: italicFont, stripDelimiterLength: 1)
        applyRegex(pattern: "`(.*?)`", in: result, font: monoFont, stripDelimiterLength: 1, color: NSColor.secondaryLabelColor)
        applyRegex(pattern: "@(.*?)@", in: result, font: monoFont, stripDelimiterLength: 1, color: NSColor.secondaryLabelColor)

        return result
    }

    private static func applyRegex(
        pattern: String,
        in attrString: NSMutableAttributedString,
        font: NSFont,
        stripDelimiterLength: Int,
        color: NSColor? = nil
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let matches = regex.matches(in: attrString.string, options: [], range: NSRange(location: 0, length: attrString.length))

        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else { continue }
            let fullRange = match.range(at: 0)
            let innerRange = match.range(at: 1)

            guard innerRange.location != NSNotFound, innerRange.length > 0 else { continue }
            let innerText = (attrString.string as NSString).substring(with: innerRange)

            var attrs: [NSAttributedString.Key: Any] = [.font: font]
            if let color {
                attrs[.foregroundColor] = color
            }

            let replacement = NSAttributedString(string: innerText, attributes: attrs)
            attrString.replaceCharacters(in: fullRange, with: replacement)
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
}
