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
    var typewriter: Bool

    init(from preferences: AppPreferences) {
        fontSize = preferences.fontSize
        lineHeight = preferences.lineHeight.multiplier
        spellCheck = preferences.spellCheck
        smartQuotes = preferences.smartQuotes
        typewriter = preferences.typewriter
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
    var vaultURL: URL?
    var onEscape: (() -> Void)?
    var onTab: (() -> Void)?
    var onBacktab: (() -> Void)?
    var onWritingToolsActiveChange: ((Bool) -> Void)?
    var onSelectionChange: ((String, NSRange) -> Void)?
    var onTranslate: ((String, NSRange) -> Void)?
    var onAttachInsertHandler: ((@escaping (String) -> Bool) -> Void)?
    var onInsertContact: (() -> Void)?
    var onInsertFile: (() -> Void)?
    var onAssetError: ((String) -> Void)?

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
        textView.vaultURL = vaultURL
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
        textView.setAccessibilityLabel("Note body editor")
        textView.setAccessibilityRole(.textArea)
        textView.setAccessibilityHelp("Main text editor for note content")
        textView.onEscape = onEscape
        textView.onTab = onTab
        textView.onBacktab = onBacktab
        textView.onTranslate = onTranslate
        textView.onInsertContact = onInsertContact
        textView.onInsertFile = onInsertFile
        textView.onAssetError = onAssetError
        onAttachInsertHandler?({ [weak editorTextView = textView] text in
            guard let editorTextView else { return false }
            editorTextView.insertTextAtCaret(text)
            return true
        })
        apply(style, to: textView)
        context.coordinator.lastStyle = style
        context.coordinator.lastDocumentID = documentID
        context.coordinator.language = language
        context.coordinator.onWritingToolsActiveChange = onWritingToolsActiveChange
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onTranslate = onTranslate
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
        guard let textView = scroll.documentView as? EditorTextView else { return }
        context.coordinator.onWritingToolsActiveChange = onWritingToolsActiveChange
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onTranslate = onTranslate
        textView.vaultURL = vaultURL
        textView.onEscape = onEscape
        textView.onTab = onTab
        textView.onBacktab = onBacktab
        textView.onTranslate = onTranslate
        textView.onInsertContact = onInsertContact
        textView.onInsertFile = onInsertFile
        textView.onAssetError = onAssetError
        onAttachInsertHandler?({ [weak editorTextView = textView] text in
            guard let editorTextView else { return false }
            editorTextView.insertTextAtCaret(text)
            return true
        })
        if #available(macOS 15.0, *), textView.isWritingToolsActive {
            return
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
        if let editorTextView = textView as? EditorTextView {
            editorTextView.style = style
        }
        textView.font = style.font
        textView.textColor = NSColor.textColor
        textView.insertionPointColor = NSColor.textColor
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor,
        ]
        if let editorTextView = textView as? EditorTextView {
            editorTextView.updatePunctuationDiscipline()
        } else {
            textView.isAutomaticQuoteSubstitutionEnabled = style.smartQuotes
            textView.isAutomaticDashSubstitutionEnabled = style.smartQuotes
            textView.isAutomaticTextReplacementEnabled = true
            textView.isContinuousSpellCheckingEnabled = style.spellCheck
            textView.isAutomaticSpellingCorrectionEnabled = style.spellCheck
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = style.lineHeight
        paragraph.paragraphSpacing = 0
        paragraph.paragraphSpacingBefore = 0
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
        var onWritingToolsActiveChange: ((Bool) -> Void)?
        var onSelectionChange: ((String, NSRange) -> Void)?
        var onTranslate: ((String, NSRange) -> Void)?
        private var whisperGeneration = 0

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView, !applyingProgrammaticText else { return }
            text.wrappedValue = textView.string
            if let editorTextView = textView as? EditorTextView {
                editorTextView.updatePunctuationDiscipline()
            }
            scheduleWhisper()
            typewriterCenterCaret(in: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let editorTextView = textView as? EditorTextView else { return }
            editorTextView.updatePunctuationDiscipline()
            let range = editorTextView.selectedRange()
            let text = TranslationState.extractSelectedText(from: editorTextView.string, range: range) ?? ""
            onSelectionChange?(text, range)
            typewriterCenterCaret(in: editorTextView)
        }

        /// Center the caret vertically when typewriter scrolling is enabled.
        /// Free from NSTextView — uses only the layout manager and scroll view.
        private func typewriterCenterCaret(in textView: NSTextView) {
            guard lastStyle?.typewriter == true else { return }
            if #available(macOS 15.0, *), textView.isWritingToolsActive { return }
            guard let scrollView = textView.enclosingScrollView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            let range = textView.selectedRange()
            guard range.location != NSNotFound else { return }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            // rect is in text container coordinates; convert to text view coordinates.
            let caretMidY = textView.textContainerOrigin.y + rect.midY
            let visibleHeight = scrollView.contentView.bounds.height
            let targetOffset = caretMidY - visibleHeight / 2

            let maxOffset = max(0, textView.frame.height - visibleHeight)
            let clampedOffset = min(max(targetOffset, 0), maxOffset)

            // Only scroll when the caret is meaningfully off-center (>1pt).
            let currentOffset = scrollView.contentView.bounds.origin.y
            guard abs(clampedOffset - currentOffset) > 1 else { return }

            scrollView.contentView.scroll(to: NSPoint(x: 0, y: clampedOffset))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        #if compiler(>=6.0)
        @available(macOS 15.0, *)
        func textViewWritingToolsWillBegin(_ textView: NSTextView) {
            onWritingToolsActiveChange?(true)
        }

        @available(macOS 15.0, *)
        func textViewWritingToolsDidEnd(_ textView: NSTextView) {
            onWritingToolsActiveChange?(false)
            applyWhisper()
        }
        #endif

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
        /// attributes and text-storage paragraph styles.
        func applyWhisper() {
            guard let textView else { return }
            if #available(macOS 15.0, *), textView.isWritingToolsActive {
                return
            }
            let nsString = textView.string as NSString
            let full = NSRange(location: 0, length: nsString.length)

            if let layoutManager = textView.layoutManager {
                layoutManager.removeTemporaryAttribute(.font, forCharacterRange: full)
                layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
                if full.length > 0 {
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

            if let storage = textView.textStorage, full.length > 0 {
                let lineHeight = lastStyle?.lineHeight ?? 1.2
                let defaultParagraph = NSMutableParagraphStyle()
                defaultParagraph.lineHeightMultiple = lineHeight
                defaultParagraph.paragraphSpacing = 0
                defaultParagraph.paragraphSpacingBefore = 0

                let headings = WhisperScan.headingLines(in: textView.string, language: language)

                textView.undoManager?.disableUndoRegistration()
                storage.beginEditing()
                storage.addAttribute(.paragraphStyle, value: defaultParagraph, range: full)
                for heading in headings {
                    let paraRange = nsString.paragraphRange(for: heading.range)
                    let headingStyle = NSMutableParagraphStyle()
                    headingStyle.lineHeightMultiple = lineHeight
                    headingStyle.paragraphSpacing = HeadingSpacingMetrics.spacingAfter
                    headingStyle.paragraphSpacingBefore = heading.isTop ? 0 : HeadingSpacingMetrics.spacingBefore
                    storage.addAttribute(.paragraphStyle, value: headingStyle, range: paraRange)
                }
                storage.endEditing()
                textView.undoManager?.enableUndoRegistration()
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
    var vaultURL: URL?
    var onEscape: (() -> Void)?
    var onTab: (() -> Void)?
    var onBacktab: (() -> Void)?
    var onTranslate: ((String, NSRange) -> Void)?
    var onInsertContact: (() -> Void)?
    var onInsertFile: (() -> Void)?
    var onAssetError: ((String) -> Void)?
    var style: EditorStyle?

    func insertTextAtCaret(_ text: String) {
        let range = selectedRange()
        let effectiveRange = (range.location == NSNotFound) ? NSRange(location: (string as NSString).length, length: 0) : range
        if shouldChangeText(in: effectiveRange, replacementString: text) {
            replaceCharacters(in: effectiveRange, with: text)
            didChangeText()
            let newLocation = effectiveRange.location + (text as NSString).length
            setSelectedRange(NSRange(location: newLocation, length: 0))
            scrollRangeToVisible(NSRange(location: newLocation, length: 0))
        }
    }

    @objc func insertContactAction(_ sender: Any?) {
        onInsertContact?()
    }

    @objc func insertFileAction(_ sender: Any?) {
        onInsertFile?()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event)
        guard isEditable else { return menu }
        menu?.addItem(NSMenuItem.separator())
        let contactItem = NSMenuItem(title: "Insert Contact…", action: #selector(insertContactAction(_:)), keyEquivalent: "")
        contactItem.target = self
        menu?.addItem(contactItem)

        let fileItem = NSMenuItem(title: "Insert File…", action: #selector(insertFileAction(_:)), keyEquivalent: "")
        fileItem.target = self
        menu?.addItem(fileItem)
        return menu
    }

    func updatePunctuationDiscipline(for range: NSRange? = nil) {
        let targetRange = range ?? selectedRange()
        let suppress = CodeFenceScan.shouldSuppressSubstitutions(in: string, for: targetRange)
        if suppress {
            isAutomaticQuoteSubstitutionEnabled = false
            isAutomaticDashSubstitutionEnabled = false
            isAutomaticTextReplacementEnabled = false
            isContinuousSpellCheckingEnabled = false
            isAutomaticSpellingCorrectionEnabled = false
        } else {
            let smartQuotes = style?.smartQuotes ?? true
            let spellCheck = style?.spellCheck ?? true
            isAutomaticQuoteSubstitutionEnabled = smartQuotes
            isAutomaticDashSubstitutionEnabled = smartQuotes
            isAutomaticTextReplacementEnabled = true
            isContinuousSpellCheckingEnabled = spellCheck
            isAutomaticSpellingCorrectionEnabled = spellCheck
        }
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        if let first = ranges.first?.rangeValue {
            updatePunctuationDiscipline(for: first)
        }
    }

    @objc func translate(_ sender: Any?) {
        let range = selectedRange()
        if range.location != NSNotFound && range.length > 0 {
            let selected = (string as NSString).substring(with: range)
            if let onTranslate {
                onTranslate(selected, range)
                return
            }
        }
        if super.responds(to: NSSelectorFromString("translate:")) {
            super.perform(NSSelectorFromString("translate:"), with: sender)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEditable else {
            super.mouseDown(with: event)
            return
        }

        let nonModifierFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if nonModifierFlags.isEmpty && event.clickCount == 1 {
            let point = convert(event.locationInWindow, from: nil)
            let charIndex = characterIndexForInsertion(at: point)

            if charIndex != NSNotFound && charIndex <= (string as NSString).length {
                if let target = CheckboxToggle.toggleAction(in: string, at: charIndex) {
                    if let window, window.firstResponder != self {
                        window.makeFirstResponder(self)
                    }
                    if let layoutManager, let textContainer {
                        let glyphRange = layoutManager.glyphRange(forCharacterRange: target.bracketRange, actualCharacterRange: nil)
                        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                        rect = rect.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
                        let hitRect = NSRect(
                            x: max(0, rect.minX - 24),
                            y: rect.minY - 4,
                            width: rect.width + 30,
                            height: rect.height + 8
                        )
                        if hitRect.contains(point) {
                            if shouldChangeText(in: target.replacementRange, replacementString: target.replacementText) {
                                replaceCharacters(in: target.replacementRange, with: target.replacementText)
                                didChangeText()
                                return
                            }
                        }
                    } else {
                        if shouldChangeText(in: target.replacementRange, replacementString: target.replacementText) {
                            replaceCharacters(in: target.replacementRange, with: target.replacementText)
                            didChangeText()
                            return
                        }
                    }
                }
            }
        }

        super.mouseDown(with: event)
    }

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

    override func insertNewline(_ sender: Any?) {
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
            super.insertNewline(sender)
            return
        }
        if let action = ListContinuation.action(in: string, selectedRange: selectedRange()) {
            if shouldChangeText(in: action.range, replacementString: action.text) {
                replaceCharacters(in: action.range, with: action.text)
                didChangeText()
                setSelectedRange(NSRange(location: action.newCaretPosition, length: 0))
                scrollRangeToVisible(NSRange(location: action.newCaretPosition, length: 0))
                return
            }
        }
        super.insertNewline(sender)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if vaultURL != nil && hasSupportedImage(in: sender.draggingPasteboard) {
            return .copy
        }
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if vaultURL != nil && hasSupportedImage(in: sender.draggingPasteboard) {
            return .copy
        }
        return super.draggingUpdated(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let vaultURL, hasSupportedImage(in: sender.draggingPasteboard) else {
            return super.performDragOperation(sender)
        }

        var links: [String] = []
        let pboard = sender.draggingPasteboard

        let classes = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pboard.readObjects(forClasses: classes, options: options) as? [URL] {
            for url in urls where AssetManager.isSupportedImage(url: url) {
                do {
                    let result = try AssetManager.importAsset(from: url, vaultURL: vaultURL)
                    links.append(result.markdownLink)
                } catch {
                    onAssetError?(error.localizedDescription)
                }
            }
        }

        if links.isEmpty,
           let filenames = pboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            for path in filenames {
                let url = URL(fileURLWithPath: path)
                if AssetManager.isSupportedImage(url: url) {
                    do {
                        let result = try AssetManager.importAsset(from: url, vaultURL: vaultURL)
                        links.append(result.markdownLink)
                    } catch {
                        onAssetError?(error.localizedDescription)
                    }
                }
            }
        }

        if links.isEmpty {
            if let pngData = pboard.data(forType: .png) {
                do {
                    let result = try AssetManager.saveAsset(data: pngData, originalFilename: "image.png", vaultURL: vaultURL)
                    links.append(result.markdownLink)
                } catch {
                    onAssetError?(error.localizedDescription)
                }
            } else if let tiffData = pboard.data(forType: .tiff),
                      let image = NSImage(data: tiffData),
                      let tiffRep = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffRep),
                      let pngData = bitmap.representation(using: .png, properties: [:]) {
                do {
                    let result = try AssetManager.saveAsset(data: pngData, originalFilename: "image.png", vaultURL: vaultURL)
                    links.append(result.markdownLink)
                } catch {
                    onAssetError?(error.localizedDescription)
                }
            }
        }

        guard !links.isEmpty else {
            return super.performDragOperation(sender)
        }

        let textToInsert = links.joined(separator: "\n\n")
        let dropPoint = convert(sender.draggingLocation, from: nil)
        let charIndex = characterIndexForInsertion(at: dropPoint)
        let range: NSRange
        if charIndex != NSNotFound && charIndex <= (string as NSString).length {
            range = NSRange(location: charIndex, length: 0)
        } else {
            range = selectedRange()
        }

        return applySmartReplacement(textToInsert, for: range)
    }

    private func hasSupportedImage(in pboard: NSPasteboard) -> Bool {
        let classes = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pboard.readObjects(forClasses: classes, options: options) as? [URL],
           urls.contains(where: { AssetManager.isSupportedImage(url: $0) }) {
            return true
        }
        if let filenames = pboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String],
           filenames.contains(where: { AssetManager.isSupportedImage(url: URL(fileURLWithPath: $0)) }) {
            return true
        }
        if pboard.types?.contains(.png) == true || pboard.types?.contains(.tiff) == true {
            return true
        }
        return false
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
        updatePunctuationDiscipline()
        if handleSmartPaste(from: NSPasteboard.general) {
            return
        }
        super.paste(sender)
    }

    override func readSelection(from pboard: NSPasteboard) -> Bool {
        updatePunctuationDiscipline()
        if handleSmartPaste(from: pboard) {
            return true
        }
        return super.readSelection(from: pboard)
    }

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        updatePunctuationDiscipline()
        if handleSmartPaste(from: pboard) {
            return true
        }
        return super.readSelection(from: pboard, type: type)
    }

    @discardableResult
    func handleSmartPaste(from pboard: NSPasteboard) -> Bool {
        let range = selectedRange()

        // In code fences, inline code backticks, or Cooklang metadata lines,
        // preserve literal ASCII characters without wrapping or markdown conversion.
        if CodeFenceScan.shouldSuppressSubstitutions(in: string, for: range) {
            return false
        }

        // 0. Image file or data paste into vault assets/
        if let vaultURL {
            let classes = [NSURL.self]
            let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
            if let urls = pboard.readObjects(forClasses: classes, options: options) as? [URL] {
                let imageURLs = urls.filter { AssetManager.isSupportedImage(url: $0) }
                if !imageURLs.isEmpty {
                    var links: [String] = []
                    for url in imageURLs {
                        do {
                            let result = try AssetManager.importAsset(from: url, vaultURL: vaultURL)
                            links.append(result.markdownLink)
                        } catch {
                            onAssetError?(error.localizedDescription)
                        }
                    }
                    if !links.isEmpty {
                        return applySmartReplacement(links.joined(separator: "\n\n"), for: range)
                    }
                }
            }

            if let pngData = pboard.data(forType: .png) {
                do {
                    let result = try AssetManager.saveAsset(data: pngData, originalFilename: "image.png", vaultURL: vaultURL)
                    return applySmartReplacement(result.markdownLink, for: range)
                } catch {
                    onAssetError?(error.localizedDescription)
                }
            } else if let tiffData = pboard.data(forType: .tiff),
                      let image = NSImage(data: tiffData),
                      let tiffRep = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffRep),
                      let pngData = bitmap.representation(using: .png, properties: [:]) {
                do {
                    let result = try AssetManager.saveAsset(data: pngData, originalFilename: "image.png", vaultURL: vaultURL)
                    return applySmartReplacement(result.markdownLink, for: range)
                } catch {
                    onAssetError?(error.localizedDescription)
                }
            }
        }

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

