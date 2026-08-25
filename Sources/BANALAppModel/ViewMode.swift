import Foundation

/// Edit | Read applies to every note; recipes are not special.
public enum ViewMode: String, Equatable, Hashable, Sendable {
    case edit
    case read
}
