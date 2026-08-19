import AppKit
import BANALCore
import SwiftUI

enum EditorTypography {
    /// ~66 characters of SF 16pt, including page insets.
    static let measureWidth: CGFloat = 680
    static let horizontalInset: CGFloat = 32
    static let titleSize: CGFloat = 26

    static func nsFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }

    static func swiftUIFont(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight)
    }
}

struct EditorStyle: Equatable {
    var fontSize: CGFloat
    var lineHeight: CGFloat
    var spellCheck: Bool
    var smartQuotes: Bool

    init(from preferences: AppPreferences) {
        fontSize = preferences.fontSize
        lineHeight = preferences.lineHeight.multiplier
        spellCheck = preferences.spellCheck
        smartQuotes = preferences.smartQuotes
    }

    var font: NSFont {
        EditorTypography.nsFont(size: fontSize)
    }
}

/// AppKit `NSTextView` wrapper. The primary editing loop is TextKit, not a webview.
struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var documentID: String
    var language: NoteLanguage
    var findToken: Int
    var focusToken: FocusToken
    var style: EditorStyle

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textColor = NSColor.textColor
        textView.insertionPointColor = NSColor.textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: EditorTypography.horizontalInset, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.string = text
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.setAccessibilityLabel("Note")
        apply(style, to: textView)
        context.coordinator.lastStyle = style
        context.coordinator.lastDocumentID = documentID
        context.coordinator.language = language
        context.coordinator.applyWhisper()

        scroll.documentView = textView
        context.coordinator.textView = textView
        focusToken.handler = { [weak textView] in
            DispatchQueue.main.async {
                textView?.window?.makeFirstResponder(textView)
            }
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        let documentChanged = context.coordinator.lastDocumentID != documentID
        if documentChanged || textView.string != text {
            let previous = textView.selectedRange()
            let selected = CaretPlacement.preferred(
                documentChanged: documentChanged,
                textUTF16Count: text.utf16.count,
                previousLocation: previous.location,
                previousLength: previous.length
            )
            context.coordinator.applyingProgrammaticText = true
            textView.undoManager?.disableUndoRegistration()
            textView.string = text
            apply(style, to: textView)
            context.coordinator.lastStyle = style
            textView.undoManager?.enableUndoRegistration()
            context.coordinator.applyingProgrammaticText = false
            textView.undoManager?.removeAllActions()
            textView.setSelectedRange(selected)
            if documentChanged {
                textView.scrollRangeToVisible(selected)
            }
            context.coordinator.language = language
            context.coordinator.lastDocumentID = documentID
            context.coordinator.applyWhisper()
        }
        if context.coordinator.lastStyle != style {
            textView.undoManager?.disableUndoRegistration()
            apply(style, to: textView)
            textView.undoManager?.enableUndoRegistration()
            context.coordinator.lastStyle = style
            context.coordinator.applyWhisper()
        }
        if context.coordinator.lastFindToken != findToken {
            context.coordinator.lastFindToken = findToken
            textView.window?.makeFirstResponder(textView)
            let sender = TextFinderSender(action: .showFindInterface)
            textView.performTextFinderAction(sender)
        }
    }

    private func apply(_ style: EditorStyle, to textView: NSTextView) {
        textView.font = style.font
        textView.textColor = NSColor.textColor
        textView.insertionPointColor = NSColor.textColor
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor,
        ]
        textView.isAutomaticQuoteSubstitutionEnabled = style.smartQuotes
        textView.isContinuousSpellCheckingEnabled = style.spellCheck
        textView.isAutomaticSpellingCorrectionEnabled = style.spellCheck
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = style.lineHeight
        textView.defaultParagraphStyle = paragraph
        let attributes: [NSAttributedString.Key: Any] = [
            .font: style.font,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraph,
            .ligature: 1,
        ]
        textView.typingAttributes = attributes
        if let storage = textView.textStorage, storage.length > 0 {
            storage.addAttributes(attributes, range: NSRange(location: 0, length: storage.length))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?
        var lastFindToken = 0
        var lastStyle: EditorStyle?
        var lastDocumentID: String?
        var applyingProgrammaticText = false
        var language: NoteLanguage = .markdown
        private var whisperWork: DispatchWorkItem?

        init(text: Binding<String>) {
            self.text = text
        }

        deinit {
            whisperWork?.cancel()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView, !applyingProgrammaticText else { return }
            text.wrappedValue = textView.string
            scheduleWhisper()
        }

        /// Coalesce whisper marks ~0.4s after the last keystroke, in the
        /// spirit of Oliver's idle pass — never inside `textDidChange`.
        private func scheduleWhisper() {
            whisperWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.applyWhisper()
            }
            whisperWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        }

        /// Rebuild the display-only marks as layout-manager temporary
        /// attributes. The storage string, undo, and Find stay
        /// character-based; the flatten in `apply(style:)` cannot wipe
        /// marks that live on the layout manager, not the storage.
        func applyWhisper() {
            whisperWork?.cancel()
            guard let textView, let layoutManager = textView.layoutManager else { return }
            if #available(macOS 15.0, *), textView.isWritingToolsActive {
                return
            }
            let full = NSRange(location: 0, length: (textView.string as NSString).length)
            layoutManager.removeTemporaryAttribute(.font, forCharacterRange: full)
            layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
            guard full.length > 0 else { return }
            let marks = WhisperScan.marks(in: textView.string, language: language)
            for mark in marks {
                let attributes: [NSAttributedString.Key: Any]
                switch mark.kind {
                case .heading:
                    let size = lastStyle?.fontSize ?? 16
                    attributes = [.font: EditorTypography.nsFont(size: size, weight: .semibold)]
                case .sigil:
                    attributes = [.foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.3)]
                }
                layoutManager.addTemporaryAttributes(attributes, forCharacterRange: mark.range)
            }
        }
    }
}

/// `NSTextView.performTextFinderAction` reads `tag` as `NSTextFinder.Action`.
private final class TextFinderSender: NSObject {
    @objc let tag: Int

    init(action: NSTextFinder.Action) {
        tag = action.rawValue
    }
}
