import Foundation

/// Inline Publish-pane checks. Invalid values still persist so a draft is not lost.
public enum PublishSettings {
    /// `nil` when empty or a usable `http`/`https` URL.
    public static func baseURLMessage(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = url.host,
            !host.isEmpty
        else {
            return "Use an http or https address."
        }
        return nil
    }

    /// Cloudflare Pages project names are lowercase letters, numbers, and hyphens.
    public static func projectNameMessage(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Enter a Cloudflare Pages project name."
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) })
            || trimmed.hasPrefix("-")
            || trimmed.hasSuffix("-")
        {
            return "Use lowercase letters, numbers, and hyphens."
        }
        return nil
    }

    /// Account IDs are usually 32 hex characters. Warn; do not block.
    public static func accountIDMessage(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let hex = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        if trimmed.count != 32 || trimmed.unicodeScalars.contains(where: { !hex.contains($0) }) {
            return "Account IDs are usually 32 hex characters."
        }
        return nil
    }
}
