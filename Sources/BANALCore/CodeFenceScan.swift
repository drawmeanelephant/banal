import Foundation

/// Utility to scan whether an insertion point or range in a note is inside
/// a fenced code block (e.g. ``` or ~~~).
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
}
