import Foundation

/// Utility to calculate list continuation and breakout actions when Return is pressed.
public enum ListContinuation: Sendable {
    public struct Action: Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            case continuation
            case breakout
        }

        public var kind: Kind
        public var range: NSRange
        public var text: String
        public var newCaretPosition: Int

        public init(kind: Kind, range: NSRange, text: String, newCaretPosition: Int) {
            self.kind = kind
            self.range = range
            self.text = text
            self.newCaretPosition = newCaretPosition
        }
    }

    private struct ParsedLine {
        var indent: String
        var prefixLength: Int
        var nextMarker: String
        var hasContent: Bool
    }

    /// Evaluates whether pressing Return at `selectedRange` in `text` should continue
    /// a list or break out of an empty list item.
    /// Returns `nil` if standard newline insertion should occur.
    public static func action(
        in text: String,
        selectedRange: NSRange
    ) -> Action? {
        guard selectedRange.length == 0 else { return nil }

        let nsString = text as NSString
        let caret = selectedRange.location
        guard caret >= 0 && caret <= nsString.length else { return nil }

        // Do not auto-continue inside code fences.
        if CodeFenceScan.isInsideCodeFence(in: text, at: caret) {
            return nil
        }

        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        nsString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: caret, length: 0))

        let lineRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
        let line = nsString.substring(with: lineRange)

        guard let parsed = parseListLine(line) else {
            return nil
        }

        if parsed.hasContent {
            let relativeCaret = caret - lineStart
            guard relativeCaret >= parsed.prefixLength else {
                return nil
            }
            let continuationText = "\n" + parsed.indent + parsed.nextMarker
            let newCaret = caret + (continuationText as NSString).length
            return Action(
                kind: .continuation,
                range: selectedRange,
                text: continuationText,
                newCaretPosition: newCaret
            )
        } else {
            // Breakout on empty list item: delete the prefix/line contents
            return Action(
                kind: .breakout,
                range: lineRange,
                text: "",
                newCaretPosition: lineStart
            )
        }
    }

    private static func parseListLine(_ line: String) -> ParsedLine? {
        let lineNSString = line as NSString

        // 1. Scan leading indentation (spaces / tabs)
        var indentEnd = 0
        while indentEnd < lineNSString.length {
            let ch = lineNSString.character(at: indentEnd)
            if ch == 0x20 || ch == 0x09 {
                indentEnd += 1
            } else {
                break
            }
        }
        let indent = lineNSString.substring(to: indentEnd)
        let rest = lineNSString.substring(from: indentEnd)

        guard !rest.isEmpty else { return nil }

        // 2. Check for task / checkbox list: `[-*+] \[[ xX]\]`
        if let checkbox = parseCheckbox(rest, indent: indent, indentLength: indentEnd) {
            return checkbox
        }

        // 3. Check for unordered bullet list: `[-*+] `
        if let bullet = parseBullet(rest, indent: indent, indentLength: indentEnd) {
            return bullet
        }

        // 4. Check for ordered numbered list: `\d+[.)] `
        if let ordered = parseOrdered(rest, indent: indent, indentLength: indentEnd) {
            return ordered
        }

        return nil
    }

    private static func parseCheckbox(_ rest: String, indent: String, indentLength: Int) -> ParsedLine? {
        let restNSString = rest as NSString
        guard restNSString.length >= 5 else {
            // Check for bare `-[ ]` or `*[ ]` or `+[ ]` without space
            if (rest.hasPrefix("-[ ]") || rest.hasPrefix("*[ ]") || rest.hasPrefix("+[ ]") ||
                rest.hasPrefix("-[x]") || rest.hasPrefix("*[x]") || rest.hasPrefix("+[x]") ||
                rest.hasPrefix("-[X]") || rest.hasPrefix("*[X]") || rest.hasPrefix("+[X]")),
               let bullet = rest.first {
                return ParsedLine(
                    indent: indent,
                    prefixLength: indentLength + restNSString.length,
                    nextMarker: "\(bullet) [ ] ",
                    hasContent: false
                )
            }
            return nil
        }

        guard let firstChar = rest.first, firstChar == "-" || firstChar == "*" || firstChar == "+" else {
            return nil
        }

        let afterBullet = rest.dropFirst(1)
        let spaceCount = afterBullet.prefix(while: { $0 == " " || $0 == "\t" }).count
        guard spaceCount > 0 else { return nil }

        let afterSpace = afterBullet.dropFirst(spaceCount)
        guard afterSpace.hasPrefix("[ ]") || afterSpace.hasPrefix("[x]") || afterSpace.hasPrefix("[X]") else {
            return nil
        }

        let afterBracket = afterSpace.dropFirst(3)
        if afterBracket.isEmpty {
            // Line ends right after "[ ]" with no trailing space: "- [ ]"
            return ParsedLine(
                indent: indent,
                prefixLength: indentLength + restNSString.length,
                nextMarker: "\(firstChar) [ ] ",
                hasContent: false
            )
        }

        let boxSpaceCount = afterBracket.prefix(while: { $0 == " " || $0 == "\t" }).count
        guard boxSpaceCount > 0 else {
            return nil
        }

        let content = afterBracket.dropFirst(boxSpaceCount)
        let prefixLength = indentLength + 1 + spaceCount + 3 + boxSpaceCount
        let hasContent = !content.trimmingCharacters(in: .whitespaces).isEmpty

        return ParsedLine(
            indent: indent,
            prefixLength: prefixLength,
            nextMarker: "\(firstChar) [ ] ",
            hasContent: hasContent
        )
    }

    private static func parseBullet(_ rest: String, indent: String, indentLength: Int) -> ParsedLine? {
        guard let firstChar = rest.first, firstChar == "-" || firstChar == "*" || firstChar == "+" else {
            return nil
        }

        let afterBullet = rest.dropFirst(1)
        let spaceCount = afterBullet.prefix(while: { $0 == " " || $0 == "\t" }).count
        guard spaceCount > 0 else { return nil }

        let content = afterBullet.dropFirst(spaceCount)
        let prefixLength = indentLength + 1 + spaceCount
        let hasContent = !content.trimmingCharacters(in: .whitespaces).isEmpty

        return ParsedLine(
            indent: indent,
            prefixLength: prefixLength,
            nextMarker: "\(firstChar) ",
            hasContent: hasContent
        )
    }

    private static func parseOrdered(_ rest: String, indent: String, indentLength: Int) -> ParsedLine? {
        let digits = rest.prefix(while: { $0.isNumber })
        guard !digits.isEmpty && digits.count <= 9 else { return nil }

        let afterDigits = rest.dropFirst(digits.count)
        guard let delim = afterDigits.first, delim == "." || delim == ")" else {
            return nil
        }

        let afterDelim = afterDigits.dropFirst(1)
        let spaceCount = afterDelim.prefix(while: { $0 == " " || $0 == "\t" }).count
        guard spaceCount > 0 else { return nil }

        let content = afterDelim.dropFirst(spaceCount)
        let num = Int(digits) ?? 0
        let nextNum = num + 1
        let prefixLength = indentLength + digits.count + 1 + spaceCount
        let hasContent = !content.trimmingCharacters(in: .whitespaces).isEmpty

        return ParsedLine(
            indent: indent,
            prefixLength: prefixLength,
            nextMarker: "\(nextNum)\(delim) ",
            hasContent: hasContent
        )
    }
}
