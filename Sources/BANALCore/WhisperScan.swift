import Foundation

/// One display-only mark. The editor applies these as layout-manager
/// temporary attributes — the storage string, undo, and Find stay
/// character-based, so a mark can never become part of the file.
public struct WhisperMark: Equatable, Sendable {
    public var kind: WhisperMarkKind
    /// UTF-16 range in the note text.
    public var range: NSRange

    public init(kind: WhisperMarkKind, range: NSRange) {
        self.kind = kind
        self.range = range
    }
}

public enum WhisperMarkKind: Equatable, Sendable {
    /// A structural line (a heading): heavier weight, same metrics.
    case heading
    /// A syntax marker (`#`, `**`, `@`, `{`, `>>`, …): dimmed, ~30% opacity.
    case sigil
}

/// Pure line scanner for the editor whisper. Local, no subprocess, no
/// CommonMark/TextMate grammar — just enough pattern matching to show the
/// shape of a note without leaving source.
public enum WhisperScan {
    /// Marks for `text` in `language`, in document order. Never mutates
    /// `text`; every returned range is a valid UTF-16 range of it.
    public static func marks(in text: String, language: NoteLanguage) -> [WhisperMark] {
        var marks: [WhisperMark] = []
        var inFence = false
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byLines) { line, lineRange, _, _ in
            var line = line ?? ""
            while line.last == "\n" || line.last == "\r" {
                line.removeLast()
            }
            let start = lineRange.lowerBound
            switch language {
            case .markdown:
                if isFence(line) {
                    inFence.toggle()
                    return
                }
                if inFence { return }
                scanMarkdown(line, start: start, text: text, into: &marks)
            case .textile:
                if line.hasPrefix(">>>") { return }
                scanTextile(line, start: start, text: text, into: &marks)
            case .cooklang:
                scanCooklang(line, start: start, text: text, into: &marks)
            }
        }
        return marks
    }

    // MARK: - Markdown

    private static func scanMarkdown(_ line: String, start: String.Index, text: String, into marks: inout [WhisperMark]) {
        let body = line.drop(while: { $0 == " " || $0 == "\t" })
        let hashes = body.prefix(while: { $0 == "#" })
        if (1...6).contains(hashes.count) {
            let afterHashes = body.index(hashes.endIndex, offsetBy: 0)
            let nextIsSpace = afterHashes == body.endIndex || body[afterHashes] == " " || body[afterHashes] == "\t"
            if nextIsSpace {
                mark(.sigil, body.startIndex..<afterHashes, in: line, start: start, text: text, into: &marks)
                markHeadingContent(afterHashes, in: body, line: line, start: start, text: text, into: &marks)
                return
            }
        }
        var blocked = backtickSpans(in: line)
        pair("**", in: line, blocked: blocked, start: start, text: text, into: &marks, blocking: &blocked)
        pair("*", in: line, blocked: blocked, start: start, text: text, into: &marks, blocking: &blocked)
        pair("_", in: line, blocked: blocked, start: start, text: text, into: &marks, blocking: &blocked)
        markdownLinks(in: line, blocked: blocked, start: start, text: text, into: &marks)
    }

    private static func markdownLinks(in line: String, blocked: [Range<String.Index>], start: String.Index, text: String, into marks: inout [WhisperMark]) {
        var cursor = line.startIndex
        while cursor < line.endIndex {
            guard let open = line[cursor...].firstIndex(of: "[") else { break }
            if isInside(open, blocked) {
                cursor = line.index(after: open)
                continue
            }
            guard let joint = line[open...].range(of: "](") else { break }
            guard let closeParen = line[joint.upperBound...].firstIndex(of: ")") else { break }
            mark(.sigil, open..<line.index(after: open), in: line, start: start, text: text, into: &marks)
            mark(.sigil, joint.lowerBound..<joint.upperBound, in: line, start: start, text: text, into: &marks)
            mark(.sigil, closeParen..<line.index(after: closeParen), in: line, start: start, text: text, into: &marks)
            cursor = line.index(after: closeParen)
        }
    }

    private static func backtickSpans(in line: String) -> [Range<String.Index>] {
        var positions: [String.Index] = []
        var cursor = line.startIndex
        while let at = line[cursor...].firstIndex(of: "`") {
            positions.append(at)
            cursor = line.index(after: at)
        }
        var spans: [Range<String.Index>] = []
        var i = 0
        while i + 1 < positions.count {
            spans.append(positions[i]..<line.index(after: positions[i + 1]))
            i += 2
        }
        return spans
    }

    // MARK: - Textile

    private static func scanTextile(_ line: String, start: String.Index, text: String, into marks: inout [WhisperMark]) {
        if line.count >= 3, line.hasPrefix("h"), let digit = line.dropFirst().first, "123456".contains(digit), line.dropFirst(2).first == "." {
            let afterDot = line.index(line.startIndex, offsetBy: 3)
            let nextIsSpace = afterDot == line.endIndex || line[afterDot] == " " || line[afterDot] == "\t"
            if nextIsSpace {
                mark(.sigil, line.startIndex..<afterDot, in: line, start: start, text: text, into: &marks)
                let body = line[afterDot...]
                markHeadingContent(body.startIndex, in: body, line: line, start: start, text: text, into: &marks)
                return
            }
        }
        var blocked: [Range<String.Index>] = []
        pair("**", in: line, blocked: blocked, start: start, text: text, into: &marks, blocking: &blocked)
        pair("*", in: line, blocked: blocked, start: start, text: text, into: &marks, blocking: &blocked)
        pair("_", in: line, blocked: blocked, start: start, text: text, into: &marks, blocking: &blocked)
        textileLinks(in: line, start: start, text: text, into: &marks)
    }

    private static func textileLinks(in line: String, start: String.Index, text: String, into marks: inout [WhisperMark]) {
        var cursor = line.startIndex
        while cursor < line.endIndex {
            guard let openQuote = line[cursor...].firstIndex(of: "\"") else { break }
            guard let joint = line[openQuote...].range(of: "\":") else { break }
            mark(.sigil, openQuote..<line.index(after: openQuote), in: line, start: start, text: text, into: &marks)
            mark(.sigil, joint.lowerBound..<joint.upperBound, in: line, start: start, text: text, into: &marks)
            cursor = line.index(after: joint.upperBound)
        }
    }

    // MARK: - Cooklang

    private static func scanCooklang(_ line: String, start: String.Index, text: String, into marks: inout [WhisperMark]) {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        if trimmed.hasPrefix(">>") {
            mark(.sigil, trimmed.startIndex..<line.index(trimmed.startIndex, offsetBy: 2), in: line, start: start, text: text, into: &marks)
            return
        }
        var cursor = line.startIndex
        while cursor < line.endIndex {
            guard let at = line[cursor...].firstIndex(where: { $0 == "@" || $0 == "#" || $0 == "~" }) else { break }
            guard let openBrace = line[at...].firstIndex(of: "{") else { break }
            guard let closeBrace = line[openBrace...].firstIndex(of: "}") else { break }
            mark(.sigil, at..<line.index(after: at), in: line, start: start, text: text, into: &marks)
            mark(.sigil, openBrace..<line.index(after: openBrace), in: line, start: start, text: text, into: &marks)
            mark(.sigil, closeBrace..<line.index(after: closeBrace), in: line, start: start, text: text, into: &marks)
            cursor = line.index(after: closeBrace)
        }
    }

    // MARK: - Shared

    private static func isFence(_ line: String) -> Bool {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        return trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~")
    }

    private static func markHeadingContent(_ afterMarkers: String.Index, in body: Substring, line: String, start: String.Index, text: String, into marks: inout [WhisperMark]) {
        var content = body[afterMarkers...].drop(while: { $0 == " " || $0 == "\t" })
        while content.last == " " || content.last == "\t" {
            content.removeLast()
        }
        if !content.isEmpty {
            mark(.heading, content.startIndex..<content.endIndex, in: line, start: start, text: text, into: &marks)
        }
    }

    private static func isInside(_ index: String.Index, _ ranges: [Range<String.Index>]) -> Bool {
        ranges.contains { $0.contains(index) }
    }

    /// Pair sequential occurrences of `delim` (odd/even) and mark each pair
    /// as sigils, requiring non-whitespace between the two. Marked ranges are
    /// appended to `blocking` so longer delimiters (`**`) win over shorter
    /// ones (`*`) and code spans stay untouched.
    private static func pair(
        _ delim: String,
        in line: String,
        blocked: [Range<String.Index>],
        start: String.Index,
        text: String,
        into marks: inout [WhisperMark],
        blocking: inout [Range<String.Index>]
    ) {
        var positions: [String.Index] = []
        var searchStart = line.startIndex
        while searchStart < line.endIndex {
            guard let found = line[searchStart...].range(of: delim) else { break }
            let at = found.lowerBound
            if !isInside(at, blocked) {
                positions.append(at)
            }
            searchStart = found.upperBound
        }
        var i = 0
        while i + 1 < positions.count {
            let open = positions[i]
            let close = positions[i + 1]
            let between = line[line.index(after: open)..<close]
            if between.contains(where: { !$0.isWhitespace }) {
                let openRange = open..<line.index(open, offsetBy: delim.count)
                let closeRange = close..<line.index(close, offsetBy: delim.count)
                mark(.sigil, openRange, in: line, start: start, text: text, into: &marks)
                mark(.sigil, closeRange, in: line, start: start, text: text, into: &marks)
                blocking.append(openRange)
                blocking.append(closeRange)
            }
            i += 2
        }
    }

    private static func mark(_ kind: WhisperMarkKind, _ sub: Range<String.Index>, in line: String, start: String.Index, text: String, into marks: inout [WhisperMark]) {
        let lower = text.index(start, offsetBy: line.distance(from: line.startIndex, to: sub.lowerBound))
        let upper = text.index(start, offsetBy: line.distance(from: line.startIndex, to: sub.upperBound))
        marks.append(WhisperMark(kind: kind, range: NSRange(lower..<upper, in: text)))
    }
}
