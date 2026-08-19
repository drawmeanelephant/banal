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
    var onEscape: (() -> Void)?
    var onTab: (() -> Void)?
    var onBacktab: (() -> Void)?

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

        let textView = EditorTextView()
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
        textView.onEscape = onEscape
        textView.onTab = onTab
        textView.onBacktab = onBacktab
        apply(style, to: textView)
        context.coordinator.lastStyle = style
        context.coordinator.lastDocumentID = documentID
        context.coordinator.language = language
        context.coordinator.applyWhisper()

        scroll.documentView = textView
        context.coordinator.textView = textView
        focusToken.handler = { [weak textView] in
            DispatchQueue.main.async {
                guard let textView, let window = textView.window else { return }
                window.makeFirstResponder(textView)
                let selected = textView.selectedRange()
                textView.scrollRangeToVisible(selected)
            }
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        if let editorTextView = textView as? EditorTextView {
            editorTextView.onEscape = onEscape
            editorTextView.onTab = onTab
            editorTextView.onBacktab = onBacktab
        }
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

    /// MainActor because `NSTextView`'s text properties and the delegate
    /// methods are MainActor-isolated on macOS 15 SDKs (and the beta SDK
    /// enforces the same shape) — the pass must not hop isolation.
    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?
        var lastFindToken = 0
        var lastStyle: EditorStyle?
        var lastDocumentID: String?
        var applyingProgrammaticText = false
        var language: NoteLanguage = .markdown
        private var whisperGeneration = 0

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView, !applyingProgrammaticText else { return }
            text.wrappedValue = textView.string
            scheduleWhisper()
        }

        /// Coalesce whisper marks ~0.4s after the last keystroke, in the
        /// spirit of Oliver's idle pass — never inside `textDidChange`.
        private func scheduleWhisper() {
            whisperGeneration += 1
            let generation = whisperGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, self.whisperGeneration == generation else { return }
                self.applyWhisper()
            }
        }

        /// Rebuild the display-only marks as layout-manager temporary
        /// attributes. The storage string, undo, and Find stay
        /// character-based; the flatten in `apply(style:)` cannot wipe
        /// marks that live on the layout manager, not the storage.
        func applyWhisper() {
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

final class EditorTextView: NSTextView {
    var onEscape: (() -> Void)?
    var onTab: (() -> Void)?
    var onBacktab: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        if let scroll = enclosingScrollView, scroll.isFindBarVisible {
            super.cancelOperation(sender)
            return
        }
        if let onEscape {
            onEscape()
        } else {
            super.cancelOperation(sender)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            if let scroll = enclosingScrollView, scroll.isFindBarVisible {
                super.keyDown(with: event)
                return
            }
            if let onEscape {
                onEscape()
                return
            }
        }
        if event.keyCode == 48 { // Tab
            let insideFence = CodeFenceScan.isInsideCodeFence(in: string, at: selectedRange().location)
            if event.modifierFlags.contains(.shift) {
                if insideFence {
                    super.keyDown(with: event)
                } else if let onBacktab {
                    onBacktab()
                } else {
                    super.keyDown(with: event)
                }
                return
            } else {
                if insideFence {
                    super.keyDown(with: event)
                } else if let onTab {
                    onTab()
                } else {
                    super.keyDown(with: event)
                }
                return
            }
        }
        super.keyDown(with: event)
    }

    override func insertTab(_ sender: Any?) {
        if CodeFenceScan.isInsideCodeFence(in: string, at: selectedRange().location) {
            super.insertTab(sender)
        } else if let onTab {
            onTab()
        } else {
            super.insertTab(sender)
        }
    }

    override func insertBacktab(_ sender: Any?) {
        if CodeFenceScan.isInsideCodeFence(in: string, at: selectedRange().location) {
            super.insertBacktab(sender)
        } else if let onBacktab {
            onBacktab()
        } else {
            super.insertBacktab(sender)
        }
    }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        var types = super.readablePasteboardTypes
        if !types.contains(.html) { types.append(.html) }
        if !types.contains(.rtf) { types.append(.rtf) }
        if !types.contains(.string) { types.append(.string) }
        if !types.contains(.URL) { types.append(.URL) }
        return types
    }

    override func paste(_ sender: Any?) {
        if handleSmartPaste(from: NSPasteboard.general) {
            return
        }
        super.paste(sender)
    }

    override func readSelection(from pboard: NSPasteboard) -> Bool {
        if handleSmartPaste(from: pboard) {
            return true
        }
        return super.readSelection(from: pboard)
    }

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        if handleSmartPaste(from: pboard) {
            return true
        }
        return super.readSelection(from: pboard, type: type)
    }

    @discardableResult
    func handleSmartPaste(from pboard: NSPasteboard) -> Bool {
        let range = selectedRange()

        // 1. Paste URL over selection: wrap into [selectedText](url)
        if range.length > 0 {
            let candidateURL = pboard.string(forType: .string) ?? pboard.string(forType: .URL)
            if let candidateURL,
               let selectedText = (string as NSString).substring(with: range) as String?,
               let link = SmartPaste.linkWrapped(selectedText: selectedText, urlString: candidateURL) {
                return applySmartReplacement(link, for: range)
            }
        }

        // 2. Clean Markdown paste from HTML / RTF
        if let html = pboard.string(forType: .html), !html.isEmpty {
            if let markdown = SmartPaste.cleanMarkdown(fromHTML: html) {
                return applySmartReplacement(markdown, for: range)
            }
        } else if let rtfData = pboard.data(forType: .rtf) {
            if let markdown = SmartPaste.cleanMarkdown(fromRTFData: rtfData) {
                return applySmartReplacement(markdown, for: range)
            }
        }

        return false
    }

    private func applySmartReplacement(_ text: String, for range: NSRange) -> Bool {
        guard shouldChangeText(in: range, replacementString: text) else {
            return false
        }
        replaceCharacters(in: range, with: text)
        didChangeText()
        let newLocation = range.location + (text as NSString).length
        setSelectedRange(NSRange(location: newLocation, length: 0))
        return true
    }
}

