import Foundation

/// Represents the converted payload ready to be placed on the pasteboard.
public struct CopyAsPayload: Equatable, Sendable {
    /// The target format requested for this payload.
    public var format: CopyAsFormat

    /// Plain text string representation (used as primary payload for Markdown or fallback for RTF/HTML).
    public var plainText: String

    /// Formatted RTF data payload for `.richText` format.
    public var rtfData: Data?

    /// Rendered HTML string payload for `.html` format.
    public var html: String?

    public init(
        format: CopyAsFormat,
        plainText: String,
        rtfData: Data? = nil,
        html: String? = nil
    ) {
        self.format = format
        self.plainText = plainText
        self.rtfData = rtfData
        self.html = html
    }
}
