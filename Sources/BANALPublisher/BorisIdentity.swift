import Foundation

/// Mirrors Boris's entity identity contract (`docs/contracts/identity-and-paths.md`,
/// Rule 2, enforced in boris `src/identity.zig`): an entity id must not contain
/// whitespace or the URL-significant `#`, `?`, `%`.
///
/// This is the Boris boundary, not a filename rule. Local note files keep their
/// plain names (#192) — `Risotto Bianco.md` stays `Risotto Bianco.md` on disk.
/// Only the ids and paths handed to the publish pipeline are made Boris-shaped.
public enum BorisIdentity {
    /// Characters Boris rejects inside an entity id.
    public static let rejectedCharacters: CharacterSet = {
        var set = CharacterSet.whitespacesAndNewlines
        set.insert(charactersIn: "#?%")
        return set
    }()

    /// True when `id` is non-empty and free of characters Boris rejects.
    public static func isValid(_ id: String) -> Bool {
        guard !id.isEmpty else { return false }
        return !id.unicodeScalars.contains { rejectedCharacters.contains($0) }
    }

    /// Rewrites a local stem or relative path into a Boris-valid entity id.
    /// Case and accents survive; rejected characters become `-`; runs collapse;
    /// `-`/`.` edges are trimmed per component; folder slashes survive as
    /// separators; an empty result falls back to `untitled`.
    public static func sanitizedEntityID(from raw: String) -> String {
        let components = raw
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { sanitizedComponent(String($0)) }
            .filter { !$0.isEmpty }
        if components.isEmpty {
            return "untitled"
        }
        return components.joined(separator: "/")
    }

    private static func sanitizedComponent(_ component: String) -> String {
        let mapped = String(
            String.UnicodeScalarView(component.unicodeScalars.map { scalar in
                rejectedCharacters.contains(scalar) ? Unicode.Scalar("-") : scalar
            })
        )
        var collapsed = mapped
        while collapsed.contains("--") {
            collapsed = collapsed.replacingOccurrences(of: "--", with: "-")
        }
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-."))
    }
}
