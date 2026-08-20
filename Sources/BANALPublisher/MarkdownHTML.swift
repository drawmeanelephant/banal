import Foundation

/// Small, deterministic Markdown subset used when the Boris binary is absent.
/// Not CommonMark-complete. Headings, paragraphs, lists, fences, links, images,
/// emphasis, and inline code are enough for the MVP publish path.
public enum MarkdownHTML {
    public static func render(_ markdown: String) -> String {
        let lines = markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        var html: [String] = []
        var index = 0
        var inList = false
        var listTag = "ul"

        func closeList() {
            if inList {
                html.append("</\(listTag)>")
                inList = false
            }
        }

        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("```") {
                closeList()
                var fence: [String] = []
                index += 1
                while index < lines.count, !lines[index].hasPrefix("```") {
                    fence.append(escape(lines[index]))
                    index += 1
                }
                html.append("<pre><code>\(fence.joined(separator: "\n"))\n</code></pre>")
                if index < lines.count { index += 1 }
                continue
            }

            if let heading = heading(line) {
                closeList()
                html.append("<h\(heading.level)>\(inline(heading.text))</h\(heading.level)>")
                index += 1
                continue
            }

            if let item = listItem(line) {
                if !inList || listTag != item.tag {
                    closeList()
                    listTag = item.tag
                    html.append("<\(listTag)>")
                    inList = true
                }
                html.append("<li>\(inline(item.text))</li>")
                index += 1
                continue
            }

            if line.hasPrefix("> ") || line == ">" {
                closeList()
                html.append("<blockquote><p>\(inline(String(line.dropFirst(min(2, line.count)))))</p></blockquote>")
                index += 1
                continue
            }

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                closeList()
                index += 1
                continue
            }

            closeList()
            html.append("<p>\(inline(line))</p>")
            index += 1
        }
        closeList()
        return html.joined(separator: "\n")
    }

    public static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func heading(_ line: String) -> (level: Int, text: String)? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        for ch in line {
            if ch == "#" { level += 1 } else { break }
        }
        guard (1...6).contains(level) else { return nil }
        let rest = line.dropFirst(level)
        guard rest.first == " " || rest.isEmpty else { return nil }
        return (level, rest.trimmingCharacters(in: .whitespaces))
    }

    private static func listItem(_ line: String) -> (tag: String, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            return ("ul", String(trimmed.dropFirst(2)))
        }
        if let dot = trimmed.firstIndex(of: "."), trimmed[..<dot].allSatisfy(\.isNumber) {
            let after = trimmed.index(after: dot)
            if after < trimmed.endIndex, trimmed[after] == " " {
                return ("ol", String(trimmed[trimmed.index(after: after)...]))
            }
        }
        return nil
    }

    private static func inline(_ text: String) -> String {
        var result = ""
        var remaining = text[...]
        while !remaining.isEmpty {
            if remaining.hasPrefix("![") {
                if let rendered = takeLink(remaining, image: true) {
                    result += rendered.html
                    remaining = rendered.rest
                    continue
                }
            }
            if remaining.hasPrefix("[") {
                if let rendered = takeLink(remaining, image: false) {
                    result += rendered.html
                    remaining = rendered.rest
                    continue
                }
            }
            if remaining.hasPrefix("`") {
                if let end = remaining.dropFirst().firstIndex(of: "`") {
                    let code = remaining[remaining.index(after: remaining.startIndex)..<end]
                    result += "<code>\(escape(String(code)))</code>"
                    remaining = remaining[remaining.index(after: end)...]
                    continue
                }
            }
            if remaining.hasPrefix("**") {
                if let end = remaining.dropFirst(2).range(of: "**") {
                    let inner = remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<end.lowerBound]
                    result += "<strong>\(escape(String(inner)))</strong>"
                    remaining = remaining[end.upperBound...]
                    continue
                }
            }
            if remaining.hasPrefix("*") {
                if let end = remaining.dropFirst().firstIndex(of: "*") {
                    let inner = remaining[remaining.index(after: remaining.startIndex)..<end]
                    result += "<em>\(escape(String(inner)))</em>"
                    remaining = remaining[remaining.index(after: end)...]
                    continue
                }
            }
            if let first = remaining.first {
                result += escape(String(first))
                remaining = remaining.dropFirst()
            } else {
                break
            }
        }
        return result
    }

    private static func takeLink(_ text: Substring, image: Bool) -> (html: String, rest: Substring)? {
        var work = text
        if image {
            guard work.first == "!" else { return nil }
            work = work.dropFirst()
        }
        guard work.first == "[" else { return nil }
        guard let closeLabel = work.firstIndex(of: "]") else { return nil }
        let label = work[work.index(after: work.startIndex)..<closeLabel]
        var after = work[work.index(after: closeLabel)...]
        guard after.first == "(" else { return nil }
        after = after.dropFirst()
        guard let closeDest = after.firstIndex(of: ")") else { return nil }
        let dest = String(after[after.startIndex..<closeDest])
        let rest = after[after.index(after: closeDest)...]
        let safeDest = escape(dest)
        let safeLabel = escape(String(label))
        if image {
            return ("<img src=\"\(safeDest)\" alt=\"\(safeLabel)\">", rest)
        }
        return ("<a href=\"\(safeDest)\">\(safeLabel)</a>", rest)
    }
}
