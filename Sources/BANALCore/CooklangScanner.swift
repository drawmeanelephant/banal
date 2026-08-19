import Foundation

/// Fast, subprocess-free scanner for Cooklang ingredient tokens and referenced sauces.
///
/// Extracts ingredient names from `@ingredient{...}` and bare `@ingredient` tokens,
/// and optionally walks referenced sauce files (`@./sauces/...`) on disk.
public enum CooklangScanner {
    /// Extract unique ingredient names from Cooklang source text.
    public static func ingredientNames(in source: String) -> [String] {
        ingredientNames(in: source, relativeTo: nil)
    }

    /// Extract unique ingredient names from Cooklang source text and referenced sauces.
    ///
    /// When `directory` is provided, referenced sauces (`@./path` or `@path/to/sauce`)
    /// are resolved, read from disk, and their ingredients are included.
    /// Walking is bounded to `maxDepth` and protected against cycles.
    public static func ingredientNames(
        in source: String,
        relativeTo directory: URL?,
        maxDepth: Int = 3
    ) -> [String] {
        var names: [String] = []
        var seen = Set<String>()
        var visitedURLs = Set<String>()

        scan(
            source: source,
            directory: directory,
            depth: 0,
            maxDepth: maxDepth,
            names: &names,
            seen: &seen,
            visitedURLs: &visitedURLs
        )

        return names
    }

    private static func scan(
        source: String,
        directory: URL?,
        depth: Int,
        maxDepth: Int,
        names: inout [String],
        seen: inout Set<String>,
        visitedURLs: inout Set<String>
    ) {
        if let directory {
            let standardPath = directory.standardizedFileURL.path
            visitedURLs.insert(standardPath)
        }

        var sauceReferences: [String] = []

        for lineSubstring in source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let rawLine = String(lineSubstring)
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(">>") || trimmed.hasPrefix("--") {
                continue
            }

            var cursor = rawLine.startIndex
            while cursor < rawLine.endIndex {
                guard let atIndex = rawLine[cursor...].firstIndex(of: "@") else { break }
                let afterAt = rawLine.index(after: atIndex)
                guard afterAt < rawLine.endIndex else { break }

                let remainder = rawLine[afterAt...]

                // Check if there is an open brace `{` on this line
                if let openBrace = remainder.firstIndex(of: "{") {
                    let between = remainder[..<openBrace]
                    // If there's another `@` before openBrace, the first `@` was a bare token
                    if let nextAt = between.firstIndex(of: "@") {
                        let bareText = remainder[..<nextAt]
                        if let (token, isSauce) = extractBareToken(from: bareText) {
                            handleToken(token, isSauce: isSauce, names: &names, seen: &seen, sauceReferences: &sauceReferences)
                        }
                        cursor = nextAt
                        continue
                    }

                    // The token is between @ and {
                    let rawToken = String(between).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !rawToken.isEmpty {
                        let isSauce = isSauceReference(rawToken)
                        handleToken(rawToken, isSauce: isSauce, names: &names, seen: &seen, sauceReferences: &sauceReferences)
                    }

                    if let closeBrace = rawLine[openBrace...].firstIndex(of: "}") {
                        cursor = rawLine.index(after: closeBrace)
                    } else {
                        cursor = rawLine.index(after: openBrace)
                    }
                } else {
                    // No brace in rest of line: bare token
                    if let (token, isSauce) = extractBareToken(from: remainder) {
                        handleToken(token, isSauce: isSauce, names: &names, seen: &seen, sauceReferences: &sauceReferences)
                        cursor = rawLine.index(after: atIndex)
                    } else {
                        cursor = rawLine.index(after: atIndex)
                    }
                }
            }
        }

        // If directory is provided and within depth bound, walk sauce references
        if let directory, depth < maxDepth {
            for ref in sauceReferences {
                guard let sauceURL = resolveSauceURL(ref, relativeTo: directory)?.standardizedFileURL else {
                    continue
                }
                let pathKey = sauceURL.path
                if visitedURLs.contains(pathKey) {
                    continue
                }
                guard let contents = try? String(contentsOf: sauceURL, encoding: .utf8) else {
                    continue
                }
                visitedURLs.insert(pathKey)
                scan(
                    source: contents,
                    directory: sauceURL.deletingLastPathComponent(),
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    names: &names,
                    seen: &seen,
                    visitedURLs: &visitedURLs
                )
            }
        }
    }

    private static func handleToken(
        _ token: String,
        isSauce: Bool,
        names: inout [String],
        seen: inout Set<String>,
        sauceReferences: inout [String]
    ) {
        if isSauce {
            sauceReferences.append(token)
        } else {
            let key = token.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                names.append(token)
            }
        }
    }

    private static func extractBareToken(from text: Substring) -> (token: String, isSauce: Bool)? {
        var token = ""
        for char in text {
            if char.isLetter || char.isNumber || char == "_" || char == "-" || char == "/" || char == "." {
                token.append(char)
            } else {
                break
            }
        }
        while token.hasSuffix(".") {
            token.removeLast()
        }
        guard !token.isEmpty else { return nil }
        let isSauce = isSauceReference(token)
        return (token, isSauce)
    }

    private static func isSauceReference(_ text: String) -> Bool {
        text.hasPrefix("./") || text.hasPrefix("../") || text.contains("/")
    }

    private static func resolveSauceURL(_ path: String, relativeTo directory: URL) -> URL? {
        var cleaned = path
        while cleaned.hasPrefix("./") {
            cleaned.removeFirst(2)
        }
        var url = directory.appendingPathComponent(cleaned)
        if url.pathExtension.isEmpty {
            url.appendPathExtension("cook")
        }
        return url
    }
}
