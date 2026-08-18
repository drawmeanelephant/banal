import Foundation

/// Where the caret should land after a buffer replace.
public enum CaretPlacement: Equatable, Sendable {
    /// New document: start. Same document: keep the old offset if it still fits.
    public static func preferred(
        documentChanged: Bool,
        textUTF16Count: Int,
        previousLocation: Int,
        previousLength: Int
    ) -> NSRange {
        if documentChanged || previousLocation > textUTF16Count {
            return NSRange(location: 0, length: 0)
        }
        let length = min(max(previousLength, 0), textUTF16Count - previousLocation)
        return NSRange(location: previousLocation, length: length)
    }
}
