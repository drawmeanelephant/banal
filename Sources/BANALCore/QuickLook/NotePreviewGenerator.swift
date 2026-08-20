import AppKit
import Foundation
import UniformTypeIdentifiers

/// Generates clean, fast, native Quick Look previews for BANAL documents (.md, .cook, .textile).
///
/// Adheres to BANAL's quiet SF Pro typography (B-1 / North Star).
/// Zero WebViews, zero external subprocesses, zero long-running background engines.
public enum NotePreviewGenerator {

    // MARK: - Public API

    /// Generate an `NSAttributedString` preview for a note file at a given URL.
    public static func attributedPreview(for fileURL: URL) -> NSAttributedString {
        guard let data = try? Data(contentsOf: fileURL),
              let source = String(data: data, encoding: .utf8) else {
            return fallbackAttributedString(title: fileURL.deletingPathExtension().lastPathComponent, body: "Unable to read note file.")
        }
        let language = NoteLanguage(pathExtension: fileURL.pathExtension) ?? .markdown
        let fallbackTitle = fileURL.deletingPathExtension().lastPathComponent
        return attributedPreview(for: source, language: language, fallbackTitle: fallbackTitle, directory: fileURL.deletingLastPathComponent())
    }

    /// Generate an `NSAttributedString` preview for raw note text and language.
    public static func attributedPreview(
        for source: String,
        language: NoteLanguage,
        fallbackTitle: String? = nil,
        directory: URL? = nil
    ) -> NSAttributedString {
        switch language {
        case .cooklang:
            return recipeAttributedPreview(for: source, fallbackTitle: fallbackTitle, directory: directory)
        case .markdown:
            return markdownAttributedPreview(for: source, fallbackTitle: fallbackTitle)
        case .textile:
            return textileAttributedPreview(for: source, fallbackTitle: fallbackTitle)
        }
    }

    /// Generate a structured recipe preview model for a Cooklang document.
    public static func recipePreview(
        for source: String,
        fallbackTitle: String? = nil,
        directory: URL? = nil
    ) -> RecipePreviewModel {
        let parsed = parseCooklangDocument(source: source, fallbackTitle: fallbackTitle, directory: directory)
        return parsed
    }

    // MARK: - Cooklang Recipe Formatting

    public struct RecipePreviewModel: Equatable, Sendable {
        public var title: String
        public var metadata: [String: String]
        public var tags: [String]
        public var ingredients: [RecipeIngredient]
        public var cookware: [String]
        public var steps: [String]

        public init(
            title: String,
            metadata: [String: String] = [:],
            tags: [String] = [],
            ingredients: [RecipeIngredient] = [],
            cookware: [String] = [],
            steps: [String] = []
        ) {
            self.title = title
            self.metadata = metadata
            self.tags = tags
            self.ingredients = ingredients
            self.cookware = cookware
            self.steps = steps
        }
    }

    public struct RecipeIngredient: Equatable, Sendable {
        public var name: String
        public var quantity: String?
        public var unit: String?
        public var isSauceReference: Bool

        public init(name: String, quantity: String? = nil, unit: String? = nil, isSauceReference: Bool = false) {
            self.name = name
            self.quantity = quantity
            self.unit = unit
            self.isSauceReference = isSauceReference
        }

        public var displayString: String {
            var parts: [String] = []
            if let quantity, !quantity.isEmpty {
                parts.append(quantity)
            }
            if let unit, !unit.isEmpty {
                parts.append(unit)
            }
            if parts.isEmpty {
                return name
            } else {
                return "\(parts.joined(separator: " ")) \(name)"
            }
        }
    }

    private static func parseCooklangDocument(
        source: String,
        fallbackTitle: String?,
        directory: URL?
    ) -> RecipePreviewModel {
        var metadata: [String: String] = [:]
        var tags: [String] = []
        var rawSteps: [String] = []
        var ingredientsMap: [String: RecipeIngredient] = [:]
        var ingredientOrder: [String] = []
        var cookwareSet = Set<String>()
        var cookwareOrder: [String] = []

        for rawLine in source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix(">>") {
                let rest = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
                if let colon = rest.firstIndex(of: ":") {
                    let key = String(rest[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
                    let val = String(rest[rest.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    if key == "tags" {
                        tags = val.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    } else {
                        metadata[key] = val
                    }
                }
                continue
            }
            if line.hasPrefix("--") || line.isEmpty {
                continue
            }

            // Extract tokens from step line
            let scanned = scanCooklangLine(line)
            for ing in scanned.ingredients {
                let key = ing.name.lowercased()
                if ingredientsMap[key] == nil {
                    ingredientsMap[key] = ing
                    ingredientOrder.append(key)
                }
            }
            for cw in scanned.cookware {
                if !cookwareSet.contains(cw.lowercased()) {
                    cookwareSet.insert(cw.lowercased())
                    cookwareOrder.append(cw)
                }
            }

            let cleanedStep = cleanCooklangStep(line)
            if !cleanedStep.isEmpty {
                rawSteps.append(cleanedStep)
            }
        }

        // Check if directory has sauces to include
        if let directory {
            let sauceIngredients = CooklangScanner.ingredientNames(in: source, relativeTo: directory)
            for name in sauceIngredients {
                let key = name.lowercased()
                if ingredientsMap[key] == nil {
                    ingredientsMap[key] = RecipeIngredient(name: name)
                    ingredientOrder.append(key)
                }
            }
        }

        let title = metadata["title"] ?? fallbackTitle ?? "Untitled Recipe"
        let ingredients = ingredientOrder.compactMap { ingredientsMap[$0] }

        return RecipePreviewModel(
            title: title,
            metadata: metadata.filter { $0.key != "title" && $0.key != "published" },
            tags: tags,
            ingredients: ingredients,
            cookware: cookwareOrder,
            steps: rawSteps
        )
    }

    private static func scanCooklangLine(_ line: String) -> (ingredients: [RecipeIngredient], cookware: [String]) {
        var ingredients: [RecipeIngredient] = []
        var cookware: [String] = []

        var cursor = line.startIndex
        while cursor < line.endIndex {
            guard let atIndex = line[cursor...].firstIndex(where: { $0 == "@" || $0 == "#" }) else { break }
            let isCookware = line[atIndex] == "#"
            let afterSigil = line.index(after: atIndex)
            guard afterSigil < line.endIndex else { break }

            let rest = line[afterSigil...]
            if let openBrace = rest.firstIndex(of: "{") {
                let tokenBetween = rest[..<openBrace]
                if let nextSigil = tokenBetween.firstIndex(where: { $0 == "@" || $0 == "#" }) {
                    // Bare token before next sigil
                    let bare = String(rest[..<nextSigil]).trimmingCharacters(in: .whitespaces)
                    if !bare.isEmpty {
                        if isCookware {
                            cookware.append(bare)
                        } else {
                            ingredients.append(RecipeIngredient(name: bare, isSauceReference: isSaucePath(bare)))
                        }
                    }
                    cursor = nextSigil
                    continue
                }

                let name = String(tokenBetween).trimmingCharacters(in: .whitespaces)
                let afterOpen = line.index(after: openBrace)
                let closeBrace = line[afterOpen...].firstIndex(of: "}") ?? line.endIndex
                let inside = String(line[afterOpen..<closeBrace]).trimmingCharacters(in: .whitespaces)

                if isCookware {
                    if !name.isEmpty { cookware.append(name) }
                } else {
                    var qty: String?
                    var unit: String?
                    if !inside.isEmpty {
                        if let pct = inside.firstIndex(of: "%") {
                            qty = String(inside[..<pct]).trimmingCharacters(in: .whitespaces)
                            unit = String(inside[inside.index(after: pct)...]).trimmingCharacters(in: .whitespaces)
                        } else {
                            qty = inside
                        }
                    }
                    if !name.isEmpty {
                        ingredients.append(RecipeIngredient(name: name, quantity: qty, unit: unit, isSauceReference: isSaucePath(name)))
                    }
                }

                cursor = closeBrace < line.endIndex ? line.index(after: closeBrace) : line.endIndex
            } else {
                // Bare token
                var bare = ""
                for ch in rest {
                    if ch.isLetter || ch.isNumber || ch == "_" || ch == "-" || ch == "/" || ch == "." {
                        bare.append(ch)
                    } else {
                        break
                    }
                }
                while bare.hasSuffix(".") { bare.removeLast() }
                if !bare.isEmpty {
                    if isCookware {
                        cookware.append(bare)
                    } else {
                        ingredients.append(RecipeIngredient(name: bare, isSauceReference: isSaucePath(bare)))
                    }
                }
                cursor = line.index(after: atIndex)
            }
        }

        return (ingredients, cookware)
    }

    private static func isSaucePath(_ token: String) -> Bool {
        token.hasPrefix("./") || token.hasPrefix("../") || token.contains("/")
    }

    private static func cleanCooklangStep(_ line: String) -> String {
        var result = ""
        var cursor = line.startIndex

        while cursor < line.endIndex {
            if line[cursor] == "@" || line[cursor] == "#" || line[cursor] == "~" {
                let sigil = line[cursor]
                let afterSigil = line.index(after: cursor)
                guard afterSigil < line.endIndex else {
                    cursor = line.index(after: cursor)
                    continue
                }
                let rest = line[afterSigil...]
                if let openBrace = rest.firstIndex(of: "{") {
                    let name = String(rest[..<openBrace]).trimmingCharacters(in: .whitespaces)
                    let afterOpen = line.index(after: openBrace)
                    let closeBrace = line[afterOpen...].firstIndex(of: "}") ?? line.endIndex
                    let inside = String(line[afterOpen..<closeBrace]).trimmingCharacters(in: .whitespaces)

                    if sigil == "~" {
                        // Timer: ~{20%minutes} -> 20 minutes
                        if let pct = inside.firstIndex(of: "%") {
                            let q = inside[..<pct].trimmingCharacters(in: .whitespaces)
                            let u = inside[inside.index(after: pct)...].trimmingCharacters(in: .whitespaces)
                            result.append("\(q) \(u)")
                        } else if !inside.isEmpty {
                            result.append("\(inside) minutes")
                        }
                    } else if sigil == "@" {
                        // Ingredient: @salt{1%tsp} -> salt
                        result.append(name.isEmpty ? inside : name)
                    } else if sigil == "#" {
                        // Cookware: #pan{} -> pan
                        result.append(name.isEmpty ? inside : name)
                    }

                    cursor = closeBrace < line.endIndex ? line.index(after: closeBrace) : line.endIndex
                    continue
                } else {
                    // Bare token
                    cursor = afterSigil
                    continue
                }
            } else {
                result.append(line[cursor])
                cursor = line.index(after: cursor)
            }
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func recipeAttributedPreview(
        for source: String,
        fallbackTitle: String?,
        directory: URL?
    ) -> NSAttributedString {
        let model = parseCooklangDocument(source: source, fallbackTitle: fallbackTitle, directory: directory)
        let result = NSMutableAttributedString()

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 4),
        ]
        result.append(NSAttributedString(string: model.title + "\n", attributes: titleAttributes))

        // Metadata row (servings, time, tags)
        var metaItems: [String] = []
        if let servings = model.metadata["servings"] {
            metaItems.append("Servings: \(servings)")
        }
        if let time = model.metadata["time"] ?? model.metadata["cook time"] {
            metaItems.append("Time: \(time)")
        }
        if !model.tags.isEmpty {
            metaItems.append(model.tags.joined(separator: ", "))
        }

        if !metaItems.isEmpty {
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .regular),
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
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 6),
            ]
            result.append(NSAttributedString(string: "Ingredients\n", attributes: sectionAttributes))

            let itemAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: listParagraphStyle(indent: 16, paragraphSpacing: 4),
            ]

            for ing in model.ingredients {
                let bullet = "•\t\(ing.displayString)\n"
                result.append(NSAttributedString(string: bullet, attributes: itemAttributes))
            }
            result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 8)]))
        }

        // Section: Instructions / Steps
        if !model.steps.isEmpty {
            let sectionAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 6),
            ]
            result.append(NSAttributedString(string: "Instructions\n", attributes: sectionAttributes))

            let stepAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: listParagraphStyle(indent: 24, paragraphSpacing: 8),
            ]

            for (idx, step) in model.steps.enumerated() {
                let stepStr = "\(idx + 1).\t\(step)\n"
                result.append(NSAttributedString(string: stepStr, attributes: stepAttributes))
            }
        }

        return result
    }

    // MARK: - Markdown Formatting

    private static func markdownAttributedPreview(
        for source: String,
        fallbackTitle: String?
    ) -> NSAttributedString {
        let parsed = (try? FrontmatterCodec.parse(source)) ?? ParsedNoteDocument(hasFrontmatter: false, frontmatter: .empty, body: source, bodyOffset: 0)
        let title = parsed.frontmatter.title ?? inferredTitle(from: parsed.body) ?? fallbackTitle ?? "Untitled"
        let tags = parsed.frontmatter.tags

        let result = NSMutableAttributedString()

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 4),
        ]
        result.append(NSAttributedString(string: title + "\n", attributes: titleAttributes))

        // Metadata
        if !tags.isEmpty || parsed.frontmatter.created != nil {
            var metaParts: [String] = []
            if let created = parsed.frontmatter.created {
                metaParts.append(DayStamp.string(from: created))
            }
            if !tags.isEmpty {
                metaParts.append(tags.joined(separator: ", "))
            }
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 12),
            ]
            result.append(NSAttributedString(string: metaParts.joined(separator: " · ") + "\n", attributes: metaAttributes))
        } else {
            result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 6)]))
        }

        // Render Markdown body
        let bodyLines = parsed.body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var inCodeFence = false
        var codeBuffer: [String] = []
        var skippedFirstHeading = (parsed.frontmatter.title == nil) // if title was inferred from first # line, skip it

        for rawLine in bodyLines {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code fence handling
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                if inCodeFence {
                    // Close fence
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
                result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 6)]))
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
                        font = NSFont.systemFont(ofSize: 19, weight: .bold)
                        spacingBefore = 12
                    case 2:
                        font = NSFont.systemFont(ofSize: 17, weight: .semibold)
                        spacingBefore = 10
                    case 3:
                        font = NSFont.systemFont(ofSize: 15, weight: .semibold)
                        spacingBefore = 8
                    default:
                        font = NSFont.systemFont(ofSize: 14, weight: .semibold)
                        spacingBefore = 6
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

            // Blockquote
            if trimmed.hasPrefix(">") {
                let quoteText = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                let quoteStyle = listParagraphStyle(indent: 16, paragraphSpacing: 6)
                let quoteAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: quoteStyle,
                ]
                result.append(NSAttributedString(string: "“\t\(quoteText)”\n", attributes: quoteAttrs))
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

    // MARK: - Textile Formatting

    private static func textileAttributedPreview(
        for source: String,
        fallbackTitle: String?
    ) -> NSAttributedString {
        let parsed = (try? FrontmatterCodec.parse(source)) ?? ParsedNoteDocument(hasFrontmatter: false, frontmatter: .empty, body: source, bodyOffset: 0)
        let title = parsed.frontmatter.title ?? inferredTitle(from: parsed.body) ?? fallbackTitle ?? "Untitled"
        let tags = parsed.frontmatter.tags

        let result = NSMutableAttributedString()

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 4),
        ]
        result.append(NSAttributedString(string: title + "\n", attributes: titleAttributes))

        // Metadata
        if !tags.isEmpty || parsed.frontmatter.created != nil {
            var metaParts: [String] = []
            if let created = parsed.frontmatter.created {
                metaParts.append(DayStamp.string(from: created))
            }
            if !tags.isEmpty {
                metaParts.append(tags.joined(separator: ", "))
            }
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle(lineSpacing: 2, paragraphSpacing: 12),
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
                    if skippedFirstHeading && level == 1 && text == title {
                        skippedFirstHeading = false
                        continue
                    }
                    let font: NSFont
                    let spacingBefore: CGFloat
                    switch level {
                    case 1:
                        font = NSFont.systemFont(ofSize: 19, weight: .bold)
                        spacingBefore = 12
                    case 2:
                        font = NSFont.systemFont(ofSize: 17, weight: .semibold)
                        spacingBefore = 10
                    case 3:
                        font = NSFont.systemFont(ofSize: 15, weight: .semibold)
                        spacingBefore = 8
                    default:
                        font = NSFont.systemFont(ofSize: 14, weight: .semibold)
                        spacingBefore = 6
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

            // Paragraph p.
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

        if inBlockCode && !codeBuffer.isEmpty {
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

    // MARK: - Inline Formatting Helpers

    private static func formatInlineMarkdown(_ text: String, baseFont: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
        ])

        let boldFont = NSFont.systemFont(ofSize: baseFont.pointSize, weight: .bold)
        let italicDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.italic)
        let italicFont = NSFont(descriptor: italicDescriptor, size: baseFont.pointSize) ?? baseFont
        let monoFont = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)

        applyRegex(pattern: "\\*\\*(.*?)\\*\\*", in: result, font: boldFont, stripDelimiterLength: 2)
        applyRegex(pattern: "__(.*?)__", in: result, font: boldFont, stripDelimiterLength: 2)
        applyRegex(pattern: "(?<!\\*)\\*(?!\\*)(.*?)(?<!\\*)\\*(?!\\*)", in: result, font: italicFont, stripDelimiterLength: 1)
        applyRegex(pattern: "(?<!_)_(?!_)(.*?)(?<!_)_(?!_)", in: result, font: italicFont, stripDelimiterLength: 1)
        applyRegex(pattern: "`(.*?)`", in: result, font: monoFont, stripDelimiterLength: 1, color: NSColor.secondaryLabelColor)

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

        applyRegex(pattern: "\\*(.*?)\\*", in: result, font: boldFont, stripDelimiterLength: 1)
        applyRegex(pattern: "_(.*?)_", in: result, font: italicFont, stripDelimiterLength: 1)
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

        // Iterate backwards so replacements do not invalidate earlier offsets
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

    private static func fallbackAttributedString(title: String, body: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: title + "\n\n", attributes: [
            .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor.labelColor,
        ]))
        result.append(NSAttributedString(string: body, attributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        return result
    }
}
