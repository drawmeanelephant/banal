import AppKit
import BANALCore
import Combine
import Foundation

/// Selection translation: presentation state for the system sheet
/// (macOS 15+), the native fallback, and replacing the selection with
/// the result.
@MainActor
public final class TranslationController: ObservableObject {
    /// Controls system translation sheet presentation (macOS 15+).
    @Published public var isPresented = false
    /// Text to present in the translation sheet.
    @Published public var text = ""

    public init() {}

    /// Whether the current editor selection can be translated.
    public func canTranslate(session: EditorSession, hasSelectedNote: Bool, viewMode: ViewMode) -> Bool {
        guard hasSelectedNote, viewMode == .edit else { return false }
        return TranslationState.isValidTranslationText(session.selectedText)
    }

    /// Present the system sheet on macOS 15+, else route through the
    /// native translate: action. Returns whether presentation state was
    /// set (the coordinator has nothing further to do).
    @discardableResult
    public func translateSelection(session: EditorSession) -> Bool {
        text = session.selectedText
        if #available(macOS 15.0, *) {
            isPresented = true
            return true
        }
        triggerNativeTranslation()
        return false
    }

    /// Swap the tracked selection for `replacement` in the buffer.
    /// Returns whether anything was replaced.
    @discardableResult
    public func replaceSelection(with replacement: String, session: EditorSession) -> Bool {
        session.replaceSelection(with: replacement)
    }

    /// The native fallback for systems without the translation sheet.
    public func triggerNativeTranslation() {
        NSApp.sendAction(NSSelectorFromString("translate:"), to: nil, from: nil)
    }

    /// A new buffer or mode change ends any open translation.
    public func reset() {
        isPresented = false
        text = ""
    }
}
