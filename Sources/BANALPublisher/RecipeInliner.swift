import Foundation

/// The result of walking a recipe's `@./path{scale}` references.
public struct InlinedRecipe: Equatable, Sendable {
    /// The source with references replaced by the target files' sources.
    public var source: String
    /// One-sentence problems: missing sauce, a reference cycle, too many
    /// levels. Read shows them; Edit is untouched either way.
    public var issues: [String]

    public init(source: String, issues: [String] = []) {
        self.source = source
        self.issues = issues
    }
}

/// Walks `@./path{scale}` references in Cooklang source — a path walk, not
/// a grammar. B-9 forbade a recipe graph; the referenced file's own source
/// is inlined into *this* Read so the sauce's ingredients cook with the
/// risotto. The recipe file on disk is never rewritten.
public enum RecipeInliner {
    /// Scales a Cooklang source by a percent (150 → `scale --factor 3/2`).
    /// Oliver does the math, never this walker.
    public typealias Scaler = @Sendable (String, Int) throws -> String

    /// Replaces every `@./path` reference (optionally `{NNN%…}`) in
    /// `source` with the target `.cook` file's source, resolved relative to
    /// `directory`. When a reference carries a percent, the target source is
    /// scaled by it before inlining. The walk is bounded to `maxTotalFiles`
    /// referenced files; a cycle or a missing file is one sentence in
    /// `issues`. References deeper than the bound are left as written.
    public static func inline(
        source: String,
        relativeTo directory: URL,
        maxTotalFiles: Int = 3,
        scaler: Scaler? = nil
    ) -> InlinedRecipe {
        var issues: [String] = []
        var budget = 0
        var stack: [String] = []
        let walked = walk(
            source: source,
            directory: directory,
            budget: &budget,
            maxTotalFiles: maxTotalFiles,
            stack: &stack,
            issues: &issues,
            scaler: scaler
        )
        return InlinedRecipe(source: walked, issues: issues)
    }

    /// `@./sauces/Hollandaise` (optional `{150%g}`), `@sauces/Hollandaise`,
    /// or a root-relative `@./B`. A path either starts with `./` or contains
    /// a `/` — plain ingredient names do neither. Dots only separate name
    /// parts, so a sentence-ending period is never swallowed.
    private static let referencePattern = #"@((?:\./)[\w\-]+(?:\.[\w\-]+)*(?:\/[\w\-]+(?:\.[\w\-]+)*)*|[\w\-]+(?:\.[\w\-]+)*\/[\w\-]+(?:\.[\w\-]+)*)(?:\{([^}]*)\})?"#

    private static func walk(
        source: String,
        directory: URL,
        budget: inout Int,
        maxTotalFiles: Int,
        stack: inout [String],
        issues: inout [String],
        scaler: Scaler?
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: referencePattern) else {
            return source
        }
        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        guard !matches.isEmpty else { return source }

        var out = source
        // Replace from the end so earlier ranges stay valid as we substitute.
        for match in matches.reversed() {
            guard
                let whole = Range(match.range, in: out),
                let nameRange = Range(match.range(at: 1), in: out)
            else { continue }
            let name = String(out[nameRange])
            let componentRange = match.range(at: 2)
            let component = componentRange.location == NSNotFound
                ? nil
                : String(out[Range(componentRange, in: out)!])
            let percent = percent(from: component)

            guard let url = resolve(name, relativeTo: directory)?.standardizedFileURL else {
                issues.append("Sauce path not found: \(name)")
                continue
            }
            let key = url.path
            if stack.contains(key) {
                issues.append("Sauce cycle: \(name)")
                continue
            }
            if budget >= maxTotalFiles {
                issues.append("Too many sauces: \(name)")
                continue
            }
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
                issues.append("Sauce not found: \(name)")
                continue
            }
            budget += 1
            stack.append(key)
            var target = walk(
                source: contents,
                directory: url.deletingLastPathComponent(),
                budget: &budget,
                maxTotalFiles: maxTotalFiles,
                stack: &stack,
                issues: &issues,
                scaler: scaler
            )
            stack.removeLast()
            target = stripMetadataLines(from: target)
            if let percent, let scaler {
                do {
                    target = try scaler(target, percent)
                } catch {
                    issues.append("Sauce didn’t scale: \(name)")
                }
            }
            out.replaceSubrange(whole, with: target)
        }
        return out
    }

    /// `{150%g}` → 150, `{50%}` → 50, `{}` / `{2}` / no braces → nil. Only a
    /// percent is a scale this card understands; a bare quantity is left alone.
    private static func percent(from component: String?) -> Int? {
        guard let component, let percentIndex = component.firstIndex(of: "%") else {
            return nil
        }
        let digits = component[..<percentIndex].trimmingCharacters(in: .whitespaces)
        guard let value = Int(digits), value > 0 else { return nil }
        return value
    }

    private static func resolve(_ path: String, relativeTo directory: URL) -> URL? {
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

    /// A target's `>> title:` header is a file header, not recipe prose.
    /// Oliver's `scale` would otherwise mangle it into `> > title:` text.
    private static func stripMetadataLines(from source: String) -> String {
        source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix(">>") }
            .joined(separator: "\n")
    }
}
