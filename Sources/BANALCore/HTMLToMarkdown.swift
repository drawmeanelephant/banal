import Foundation

/// Fast, compact, synchronous HTML to Markdown converter.
/// Converts standard web / rich-text formatting (headings, emphasis, links,
/// lists, blockquotes, code blocks) into clean Markdown while stripping
/// CSS spans, classes, divs, scripts, styles, and unwanted markup.
public enum HTMLToMarkdown {
    public static func convert(_ html: String) -> String {
        let cleanHTML = preprocess(html)
        guard !cleanHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        let root = HTMLParser.parse(cleanHTML)
        let markdown = root.renderMarkdown().trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanNewlines(markdown)
    }

    private static func preprocess(_ html: String) -> String {
        var str = html
        // Strip HTML comments <!-- ... -->
        str = replacePattern(#"<!--[\s\S]*?-->"#, in: str, with: "")
        // Strip <head>...</head>, <style>...</style>, <script>...</script>, <svg>...</svg>
        str = replacePattern(#"(?i)<head[^>]*>[\s\S]*?<\/head>"#, in: str, with: "")
        str = replacePattern(#"(?i)<style[^>]*>[\s\S]*?<\/style>"#, in: str, with: "")
        str = replacePattern(#"(?i)<script[^>]*>[\s\S]*?<\/script>"#, in: str, with: "")
        str = replacePattern(#"(?i)<svg[^>]*>[\s\S]*?<\/svg>"#, in: str, with: "")
        return str
    }

    private static func replacePattern(_ pattern: String, in text: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }

    private static func cleanNewlines(_ text: String) -> String {
        // Collapse 3 or more consecutive newlines into 2
        var result = replacePattern(#"\n{3,}"#, in: text, with: "\n\n")
        // Remove trailing spaces on each line
        result = replacePattern(#"[ \t]+(?=\n|$)"#, in: result, with: "")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func decodeEntities(_ text: String) -> String {
        var str = text
        guard str.contains("&") else { return str }

        let namedEntities: [String: String] = [
            "&quot;": "\"",
            "&amp;": "&",
            "&apos;": "'",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " ",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&lsquo;": "‘",
            "&rsquo;": "’",
            "&ldquo;": "“",
            "&rdquo;": "”",
            "&bull;": "•",
            "&middot;": "·",
            "&cent;": "¢",
            "&pound;": "£",
            "&euro;": "€",
            "&yen;": "¥",
            "&sect;": "§",
            "&para;": "¶",
            "&deg;": "°",
            "&plusmn;": "±",
            "&times;": "×",
            "&divide;": "÷",
            "&larr;": "←",
            "&rarr;": "→",
            "&uarr;": "↑",
            "&darr;": "↓",
        ]

        for (entity, char) in namedEntities {
            str = str.replacingOccurrences(of: entity, with: char)
        }

        // Numeric decimal entities: &#123;
        if let regex = try? NSRegularExpression(pattern: #"&#([0-9]{1,7});"#, options: []) {
            let nsStr = str as NSString
            let matches = regex.matches(in: str, options: [], range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                let codeStr = nsStr.substring(with: match.range(at: 1))
                if let code = UInt32(codeStr), let scalar = UnicodeScalar(code) {
                    let character = String(Character(scalar))
                    str = (str as NSString).replacingCharacters(in: match.range, with: character)
                }
            }
        }

        // Numeric hex entities: &#x1F600;
        if let regex = try? NSRegularExpression(pattern: #"&#[xX]([0-9a-fA-F]{1,6});"#, options: []) {
            let nsStr = str as NSString
            let matches = regex.matches(in: str, options: [], range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                let codeStr = nsStr.substring(with: match.range(at: 1))
                if let code = UInt32(codeStr, radix: 16), let scalar = UnicodeScalar(code) {
                    let character = String(Character(scalar))
                    str = (str as NSString).replacingCharacters(in: match.range, with: character)
                }
            }
        }

        return str
    }
}

// MARK: - HTML AST and Parser

private final class HTMLNode {
    enum Kind {
        case root
        case text(String)
        case element(tag: String, attributes: [String: String])
    }

    let kind: Kind
    var children: [HTMLNode] = []
    weak var parent: HTMLNode?

    init(kind: Kind) {
        self.kind = kind
    }

    func addChild(_ child: HTMLNode) {
        child.parent = self
        children.append(child)
    }

    struct RenderContext {
        var inPre = false
        var listStack: [ListContext] = []
        var blockquoteDepth = 0
    }

    struct ListContext {
        var isOrdered: Bool
        var counter: Int
    }

    func renderMarkdown(context: RenderContext = RenderContext()) -> String {
        switch kind {
        case .root:
            var out = ""
            for child in children {
                out += child.renderMarkdown(context: context)
            }
            return out

        case .text(let text):
            if context.inPre {
                return text
            }
            return text

        case .element(let tag, let attrs):
            return renderElement(tag: tag, attrs: attrs, context: context)
        }
    }

    private func renderChildren(context: RenderContext) -> String {
        var out = ""
        for child in children {
            out += child.renderMarkdown(context: context)
        }
        return out
    }

    private func renderElement(tag: String, attrs: [String: String], context: RenderContext) -> String {
        switch tag {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(tag.dropFirst()) ?? 1
            let inner = renderChildren(context: context).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !inner.isEmpty else { return "" }
            let prefix = String(repeating: "#", count: level)
            return "\n\n\(prefix) \(inner)\n\n"

        case "p":
            let inner = renderChildren(context: context).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !inner.isEmpty else { return "" }
            return "\n\n\(inner)\n\n"

        case "div":
            let inner = renderChildren(context: context)
            guard !inner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
            return "\n\(inner)\n"

        case "blockquote":
            var ctx = context
            ctx.blockquoteDepth += 1
            let inner = renderChildren(context: ctx).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !inner.isEmpty else { return "" }
            let quotePrefix = String(repeating: "> ", count: ctx.blockquoteDepth)
            let lines = inner.components(separatedBy: "\n")
            let quoted = lines.map { line in
                line.isEmpty ? ">" : "\(quotePrefix)\(line)"
            }.joined(separator: "\n")
            return "\n\n\(quoted)\n\n"

        case "pre":
            var ctx = context
            ctx.inPre = true
            let inner = renderChildren(context: ctx).trimmingCharacters(in: .newlines)
            guard !inner.isEmpty else { return "" }
            return "\n\n```\n\(inner)\n```\n\n"

        case "code":
            if context.inPre {
                return renderChildren(context: context)
            }
            let inner = renderChildren(context: context)
            guard !inner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
            return "`\(inner)`"

        case "b", "strong":
            let inner = renderChildren(context: context)
            guard !inner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return inner }
            return wrapInline(inner, prefix: "**", suffix: "**")

        case "i", "em":
            let inner = renderChildren(context: context)
            guard !inner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return inner }
            return wrapInline(inner, prefix: "*", suffix: "*")

        case "s", "del", "strike":
            let inner = renderChildren(context: context)
            guard !inner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return inner }
            return wrapInline(inner, prefix: "~~", suffix: "~~")

        case "a":
            let inner = renderChildren(context: context)
            let href = attrs["href"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if href.isEmpty {
                return inner
            }
            if inner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "[\(href)](\(href))"
            }
            return wrapInlineLink(inner: inner, url: href)

        case "img":
            let src = attrs["src"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !src.isEmpty else { return "" }
            let alt = attrs["alt"] ?? ""
            return "![\(alt)](\(src))"

        case "ul":
            let isNested = !context.listStack.isEmpty
            var ctx = context
            ctx.listStack.append(ListContext(isOrdered: false, counter: 1))
            let inner = renderListItems(context: ctx).trimmingCharacters(in: .newlines)
            guard !inner.isEmpty else { return "" }
            return isNested ? "\n\(inner)" : "\n\n\(inner)\n\n"

        case "ol":
            let isNested = !context.listStack.isEmpty
            var ctx = context
            var start = 1
            if let startAttr = attrs["start"], let parsed = Int(startAttr) {
                start = parsed
            }
            ctx.listStack.append(ListContext(isOrdered: true, counter: start))
            let inner = renderListItems(context: ctx).trimmingCharacters(in: .newlines)
            guard !inner.isEmpty else { return "" }
            return isNested ? "\n\(inner)" : "\n\n\(inner)\n\n"

        case "li":
            let isOrdered = context.listStack.last?.isOrdered ?? false
            let bullet: String
            if isOrdered {
                let counter = context.listStack.last?.counter ?? 1
                bullet = "\(counter). "
            } else {
                bullet = "- "
            }
            let depth = max(0, context.listStack.count - 1)
            let indent = String(repeating: "  ", count: depth)

            var inlineParts = ""
            var nestedParts = ""
            for child in children {
                if case .element(let tag, _) = child.kind, (tag == "ul" || tag == "ol") {
                    nestedParts += child.renderMarkdown(context: context)
                } else {
                    inlineParts += child.renderMarkdown(context: context)
                }
            }
            let trimmedInline = inlineParts.trimmingCharacters(in: .whitespacesAndNewlines)
            var result = ""
            if !trimmedInline.isEmpty {
                result += "\(indent)\(bullet)\(trimmedInline)"
            }
            if !nestedParts.isEmpty {
                if !result.isEmpty && !nestedParts.hasPrefix("\n") {
                    result += "\n"
                }
                result += nestedParts
            }
            return result

        case "br":
            return "\n"

        case "hr":
            return "\n\n---\n\n"

        default:
            // Generic container (span, font, section, article, table, tr, td, th, etc.)
            return renderChildren(context: context)
        }
    }

    private func renderListItems(context: RenderContext) -> String {
        var out = ""
        var currentContext = context

        for child in children {
            if case .element(let tag, _) = child.kind, tag == "li" {
                let itemText = child.renderMarkdown(context: currentContext)
                if !itemText.isEmpty {
                    out += "\(itemText)\n"
                }
                if let lastList = currentContext.listStack.last, lastList.isOrdered {
                    if var mutable = currentContext.listStack.popLast() {
                        mutable.counter += 1
                        currentContext.listStack.append(mutable)
                    }
                }
            } else {
                let text = child.renderMarkdown(context: currentContext)
                if !text.isEmpty {
                    out += text
                }
            }
        }
        return out
    }

    private func wrapInline(_ text: String, prefix: String, suffix: String) -> String {
        let leadingSpaces = text.prefix(while: { $0.isWhitespace || $0.isNewline })
        let trailingSpaces = String(text.reversed().prefix(while: { $0.isWhitespace || $0.isNewline }).reversed())
        let startIdx = text.index(text.startIndex, offsetBy: leadingSpaces.count)
        let endIdx = text.index(text.endIndex, offsetBy: -trailingSpaces.count)
        guard startIdx < endIdx else { return text }
        let trimmed = text[startIdx..<endIdx]
        return "\(leadingSpaces)\(prefix)\(trimmed)\(suffix)\(trailingSpaces)"
    }

    private func wrapInlineLink(inner: String, url: String) -> String {
        let leadingSpaces = inner.prefix(while: { $0.isWhitespace || $0.isNewline })
        let trailingSpaces = String(inner.reversed().prefix(while: { $0.isWhitespace || $0.isNewline }).reversed())
        let startIdx = inner.index(inner.startIndex, offsetBy: leadingSpaces.count)
        let endIdx = inner.index(inner.endIndex, offsetBy: -trailingSpaces.count)
        guard startIdx < endIdx else { return "[\(url)](\(url))" }
        let trimmed = inner[startIdx..<endIdx]
        return "\(leadingSpaces)[\(trimmed)](\(url))\(trailingSpaces)"
    }
}

private enum HTMLParser {
    static let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]

    static func parse(_ html: String) -> HTMLNode {
        let root = HTMLNode(kind: .root)
        var current = root

        var index = html.startIndex
        let endIndex = html.endIndex

        while index < endIndex {
            if html[index] == "<" {
                // Find closing '>'
                var tagEnd = html.index(after: index)
                var inQuote: Character? = nil

                while tagEnd < endIndex {
                    let char = html[tagEnd]
                    if let quote = inQuote {
                        if char == quote {
                            inQuote = nil
                        }
                    } else if char == "\"" || char == "'" {
                        inQuote = char
                    } else if char == ">" {
                        break
                    }
                    tagEnd = html.index(after: tagEnd)
                }

                if tagEnd < endIndex, html[tagEnd] == ">" {
                    let tagContent = html[html.index(after: index)..<tagEnd].trimmingCharacters(in: .whitespacesAndNewlines)
                    index = html.index(after: tagEnd)

                    if tagContent.hasPrefix("/") {
                        // Closing tag
                        let tagName = tagContent.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        var search: HTMLNode? = current
                        while let node = search {
                            if case .element(let tag, _) = node.kind, tag == tagName {
                                current = node.parent ?? root
                                break
                            }
                            search = node.parent
                        }
                    } else if !tagContent.isEmpty {
                        // Opening or self-closing tag
                        let (tagName, attributes, isSelfClosing) = parseTag(tagContent)
                        guard !tagName.isEmpty else { continue }

                        let element = HTMLNode(kind: .element(tag: tagName, attributes: attributes))
                        current.addChild(element)

                        if !isSelfClosing && !voidElements.contains(tagName) {
                            current = element
                        }
                    }
                    continue
                }
            }

            // Text chunk
            var textEnd = html.index(after: index)
            while textEnd < endIndex, html[textEnd] != "<" {
                textEnd = html.index(after: textEnd)
            }

            let text = String(html[index..<textEnd])
            let decoded = HTMLToMarkdown.decodeEntities(text)
            if !decoded.isEmpty {
                current.addChild(HTMLNode(kind: .text(decoded)))
            }
            index = textEnd
        }

        return root
    }

    private static func parseTag(_ content: String) -> (name: String, attributes: [String: String], isSelfClosing: Bool) {
        var str = content
        let isSelfClosing = str.hasSuffix("/")
        if isSelfClosing {
            str = String(str.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var attributes: [String: String] = [:]
        var scanner = str[...]

        // Extract tag name
        let nameChunk = scanner.prefix(while: { !$0.isWhitespace && $0 != "/" })
        let tagName = String(nameChunk).lowercased()
        scanner = scanner.dropFirst(nameChunk.count)

        // Parse attributes: attr="value" or attr='value' or attr=value or bare attr
        while !scanner.isEmpty {
            scanner = scanner.drop(while: { $0.isWhitespace || $0 == "/" })
            guard !scanner.isEmpty else { break }

            let attrNameChunk = scanner.prefix(while: { !$0.isWhitespace && $0 != "=" && $0 != "/" && $0 != ">" })
            guard !attrNameChunk.isEmpty else {
                scanner = scanner.dropFirst()
                continue
            }
            let attrName = String(attrNameChunk).lowercased()
            scanner = scanner.dropFirst(attrNameChunk.count)

            scanner = scanner.drop(while: { $0.isWhitespace })
            if scanner.first == "=" {
                scanner = scanner.dropFirst()
                scanner = scanner.drop(while: { $0.isWhitespace })
                var attrVal = ""
                if let quote = scanner.first, quote == "\"" || quote == "'" {
                    scanner = scanner.dropFirst()
                    let valChunk = scanner.prefix(while: { $0 != quote })
                    attrVal = String(valChunk)
                    scanner = scanner.dropFirst(valChunk.count)
                    if scanner.first == quote {
                        scanner = scanner.dropFirst()
                    }
                } else {
                    let valChunk = scanner.prefix(while: { !$0.isWhitespace && $0 != ">" && $0 != "/" })
                    attrVal = String(valChunk)
                    scanner = scanner.dropFirst(valChunk.count)
                }
                attributes[attrName] = HTMLToMarkdown.decodeEntities(attrVal)
            } else {
                attributes[attrName] = ""
            }
        }

        return (tagName, attributes, isSelfClosing)
    }
}
