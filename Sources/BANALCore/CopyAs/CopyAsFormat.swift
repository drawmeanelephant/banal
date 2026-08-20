import Foundation

/// Supported clipboard formats for Edit → Copy As.
public enum CopyAsFormat: String, CaseIterable, Sendable {
    case markdown
    case richText
    case html

    /// User-facing format name for menus and UI.
    public var title: String {
        switch self {
        case .markdown:
            return "Markdown"
        case .richText:
            return "Rich Text"
        case .html:
            return "HTML"
        }
    }
}
