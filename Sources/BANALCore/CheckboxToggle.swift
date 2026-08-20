import Foundation

/// Utility to detect and toggle task list / checkbox items (`- [ ]`, `- [x]`, `* [ ]`, `+ [ ]`) in text buffers.
public enum CheckboxToggle: Sendable {
    public struct CheckboxItem: Equatable, Sendable {
        public var lineRange: NSRange
        public var bracketRange: NSRange
        public var innerRange: NSRange
        public var isChecked: Bool
        public var toggledCharacter: String

        public var replacementRange: NSRange { innerRange }
        public var replacementText: String { toggledCharacter }

        public init(
            lineRange: NSRange,
            bracketRange: NSRange,
            innerRange: NSRange,
            isChecked: Bool,
            toggledCharacter: String
        ) {
            self.lineRange = lineRange
            self.bracketRange = bracketRange
            self.innerRange = innerRange
            self.isChecked = isChecked
            self.toggledCharacter = toggledCharacter
        }
    }

    /// Evaluates whether a click/action at `characterIndex` in `text` targets a checkbox prefix.
    /// Returns `nil` if the character index is outside a checkbox line, on text content, or inside a code fence.
    public static func toggleAction(
        in text: String,
        at characterIndex: Int
    ) -> CheckboxItem? {
        let nsString = text as NSString
        guard characterIndex >= 0 && characterIndex <= nsString.length else { return nil }

        // Suppress toggling inside code fences
        if CodeFenceScan.isInsideCodeFence(in: text, at: characterIndex) {
            return nil
        }

        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        nsString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: characterIndex, length: 0))

        let lineRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
        let line = nsString.substring(with: lineRange)

        guard let parsed = parseCheckboxInLine(line, lineStartOffset: lineStart) else {
            return nil
        }

        // Hit target: from start of list marker (after indentation) up to the closing bracket (plus optional trailing space)
        let hitStart = parsed.clickableStart
        let hitEnd = parsed.clickableEnd

        if characterIndex >= hitStart && characterIndex <= hitEnd {
            return parsed.item
        }

        return nil
    }

    /// Parses a single line string to determine if it contains a task list checkbox at the start.
    public static func findCheckbox(in line: String, lineStartOffset: Int = 0) -> CheckboxItem? {
        parseCheckboxInLine(line, lineStartOffset: lineStartOffset)?.item
    }

    private struct ParsedResult {
        var item: CheckboxItem
        var clickableStart: Int
        var clickableEnd: Int
    }

    private static func parseCheckboxInLine(_ line: String, lineStartOffset: Int) -> ParsedResult? {
        let lineNSString = line as NSString
        guard lineNSString.length >= 3 else { return nil }

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

        let rest = lineNSString.substring(from: indentEnd)
        let restNSString = rest as NSString
        guard restNSString.length >= 3 else { return nil }

        var bulletOffset = 0
        let firstChar = restNSString.character(at: 0)

        // Check for bullet `- `, `* `, `+ ` or bare `-`, `*`, `+`
        if firstChar == 0x2D /* - */ || firstChar == 0x2A /* * */ || firstChar == 0x2B /* + */ {
            bulletOffset = 1
            while bulletOffset < restNSString.length {
                let ch = restNSString.character(at: bulletOffset)
                if ch == 0x20 || ch == 0x09 {
                    bulletOffset += 1
                } else {
                    break
                }
            }
        }

        let afterBullet = restNSString.substring(from: bulletOffset)
        let afterBulletNSString = afterBullet as NSString
        guard afterBulletNSString.length >= 3 else { return nil }

        // Must start with `[`
        guard afterBulletNSString.character(at: 0) == 0x5B /* [ */ else { return nil }

        let markChar = afterBulletNSString.character(at: 1)
        guard afterBulletNSString.character(at: 2) == 0x5D /* ] */ else { return nil }

        let isChecked: Bool
        let toggledChar: String

        if markChar == 0x20 /* space */ {
            isChecked = false
            toggledChar = "x"
        } else if markChar == 0x78 /* x */ || markChar == 0x58 /* X */ {
            isChecked = true
            toggledChar = " "
        } else {
            return nil
        }

        let bracketAbsoluteStart = lineStartOffset + indentEnd + bulletOffset
        let bracketRange = NSRange(location: bracketAbsoluteStart, length: 3)
        let innerRange = NSRange(location: bracketAbsoluteStart + 1, length: 1)
        let lineRange = NSRange(location: lineStartOffset, length: lineNSString.length)

        let clickableStart = lineStartOffset + indentEnd
        // Allow clicking on bullet and checkbox brackets up to closing `]`
        let clickableEnd = bracketAbsoluteStart + 2

        let item = CheckboxItem(
            lineRange: lineRange,
            bracketRange: bracketRange,
            innerRange: innerRange,
            isChecked: isChecked,
            toggledCharacter: toggledChar
        )

        return ParsedResult(
            item: item,
            clickableStart: clickableStart,
            clickableEnd: clickableEnd
        )
    }
}
