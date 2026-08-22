import AppKit
import SwiftUI

/// Single global typographic pairing for BANAL — system-honest.
///
/// This is the one stylesheet (review §10 #3, issue #160). It is not per-note,
/// not per-folder, not a theme store, and not a serif personality. The pairing
/// is SF Pro for prose/UI + SF Mono for code, both from the system. No bundled
/// fonts, no custom display face, no webviews in the editing loop.
///
/// All surfaces — editor (NSTextView), Prose Read, Recipe Read, Quick Look,
/// Print, and the published site (`boris.css` using `system-ui`) — derive from
/// the same pairing. The only user control is body size (13–22, default 16) and
/// line height / measure, both global in Settings → Editor. See `AppPreferences`.
///
/// The values are intentionally quiet: title heavier than body, headings as
/// weight not hue, code as mono, measure capped at ~66 characters (680pt) so
/// a wide window stays a page, not a lawn.
public enum BanalTypography {
    /// ~66 characters of SF 16pt, including page insets. Matches
    /// `QUALITY.md` and `B-1-type.md`. Shared by editor, read views, and
    /// the published site (`max-width: 42rem` ≈ 672pt).
    public static let measureWidth: CGFloat = 680
    public static let horizontalInset: CGFloat = 32
    public static let titleSize: CGFloat = 26

    /// Body size range enforced in Settings (see `AppPreferences.fontSize`).
    public static let bodySizeRange: ClosedRange<CGFloat> = 13...22
    public static let defaultBodySize: CGFloat = 16

    /// Heading scale — weight, not color. Same metrics as body.
    /// Used by editor whisper, Quick Look, Print, and publish preview.
    public enum Heading: Sendable {
        case h1, h2, h3, h4

        public var pointSize: CGFloat {
            switch self {
            case .h1: return 19
            case .h2: return 17
            case .h3: return 15
            case .h4: return 14
            }
        }

        public var weight: NSFont.Weight {
            switch self {
            case .h1: return .bold
            default: return .semibold
            }
        }

        public var swiftUIWeight: Font.Weight {
            switch self {
            case .h1: return .bold
            default: return .semibold
            }
        }
    }

    /// Print is slightly smaller but same pairing (SF + Mono).
    public enum PrintScale: Sendable {
        public static let titleSize: CGFloat = 20
        public static let bodySize: CGFloat = 11
        public static let metaSize: CGFloat = 10
    }

    // MARK: - System-honest factories

    /// SF Pro at size/weight — never a bundled font. System-honest.
    public static func nsFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }

    /// SwiftUI system font — same family as `nsFont`.
    public static func swiftUIFont(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight)
    }

    /// SF Mono — code fences, inline `code`, Cooklang sigils. Not a theme.
    public static func monoFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    /// System font stack for the published site. Single global pairing with the
    /// app — `system-ui` resolves to San Francisco on macOS. No serif, no
    /// custom webfonts, no per-note CSS. See `review/themes/boris/assets/css/boris.css`.
    public static let cssSystemFontStack = "system-ui, -apple-system, \"SF Pro Text\", \"SF Pro Display\", \"Segoe UI\", sans-serif"
    public static let cssMonoStack = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
}
