import Foundation

/// Utility to scan whether an insertion point or range in a note is inside
/// a fenced code block, inline code span, or Cooklang metadata line.
public enum CodeFenceScan: Sendable {
    /// Returns true if the given character offset (UTF-16) is within a fenced
    /// code block.
    public static func isInsideCodeFence(in text: String, at location: Int) -> Bool {
        let nsString = text as NSString
        let safeLocation = max(0, min(location, nsString.length))
        var inFence = false
        var index = 0

        while index < safeLocation {
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            nsString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: index, length: 0))
            let lineRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
            let line = nsString.substring(with: lineRange).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                inFence.toggle()
            }
            if lineEnd <= index {
                break
            }
            index = lineEnd
        }
        return inFence
    }

    /// Returns true if the given character offset (UTF-16) is inside an inline
    /// backtick span on the current line.
    public static func isInsideInlineCode(in text: String, at location: Int) -> Bool {
        let nsString = text as NSString
        guard nsString.length > 0 else { return false }
        let safeLocation = max(0, min(location, nsString.length))

        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        nsString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: safeLocation, length: 0))

        let offsetInLine = safeLocation - lineStart
        guard offsetInLine > 0 else { return false }

        let lineRange = NSRange(location: lineStart, length: min(offsetInLine, contentsEnd - lineStart))
        let linePrefix = nsString.substring(with: lineRange)

        var backtickCount = 0
        for char in linePrefix where char == "`" {
            backtickCount += 1
        }
        return backtickCount % 2 == 1
    }

    /// Returns true if the given character offset (UTF-16) is on a Cooklang
    /// metadata line starting with `>>`.
    public static func isCooklangMetadataLine(in text: String, at location: Int) -> Bool {
        let nsString = text as NSString
        guard nsString.length > 0 else { return false }
        let safeLocation = max(0, min(location, nsString.length))

        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        nsString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: safeLocation, length: 0))

        let lineRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
        let line = nsString.substring(with: lineRange)
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        return trimmed.hasPrefix(">>")
    }

    /// Returns true if dynamic punctuation substitutions (smart quotes, smart dashes,
    /// automatic text replacement, spell checking) should be suppressed at `location`.
    public static func shouldSuppressSubstitutions(in text: String, at location: Int) -> Bool {
        if isInsideCodeFence(in: text, at: location) {
            return true
        }
        if isInsideInlineCode(in: text, at: location) {
            return true
        }
        if isCooklangMetadataLine(in: text, at: location) {
            return true
        }
        return false
    }

    /// Returns true if dynamic punctuation substitutions should be suppressed for `range`.
    public static func shouldSuppressSubstitutions(in text: String, for range: NSRange) -> Bool {
        shouldSuppressSubstitutions(in: text, at: range.location)
    }
}
