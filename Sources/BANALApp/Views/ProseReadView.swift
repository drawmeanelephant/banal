import AppKit
import SwiftUI

/// Native, read-only page for Oliver's HTML render of a Markdown or
/// Textile note. Edit is the file; Read is secondary — this view never
/// takes typing, so it is not the editor and cannot replace TextKit.
///
/// Oliver's fragment (headings, paragraphs, lists, emphasis, links) is
/// imported with the system HTML importer and remapped onto B-1 type:
/// the user's body size, weight and italic traits kept, SF throughout.
/// Missing Oliver is one sentence; a configured-but-pending render says
/// Reading… — never a fake Swift CommonMark.
struct ProseReadView: NSViewRepresentable {
    /// Oliver's HTML for the current buffer, or nil while unrendered.
    var html: String?
    /// True when no render binary is configured.
    var needsOliver: Bool
    var style: EditorStyle

    func makeCoordinator() -> Coordinator {
        Coordinator()
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
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: EditorTypography.horizontalInset, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.setAccessibilityLabel("Note prose read view")
        textView.setAccessibilityRole(.textArea)
        textView.setAccessibilityHelp("Rendered note preview")

        scroll.documentView = textView
        context.coordinator.textView = textView
        render(into: textView, coordinator: context.coordinator)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        render(into: textView, coordinator: context.coordinator)
    }

    /// Rebuild only when the content actually changed — the model republishes
    /// the render on idle, and the edit view must stay untouched.
    private func render(into textView: NSTextView, coordinator: Coordinator) {
        let key = Self.contentKey(html: html, needsOliver: needsOliver)
        guard coordinator.lastKey != key else { return }
        coordinator.lastKey = key

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = style.lineHeight

        let body: NSAttributedString
        if let html {
            body = Self.attributedPage(html: html, fontSize: style.fontSize, paragraph: paragraph)
        } else {
            let message = needsOliver ? "This note needs Oliver." : "Reading…"
            body = NSAttributedString(
                string: message,
                attributes: [
                    .font: EditorTypography.nsFont(size: style.fontSize),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: paragraph,
                ]
            )
        }
        textView.textStorage?.setAttributedString(body)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
    }

    /// Import Oliver's HTML, then remap every run onto B-1 type: the user's
    /// body size with the importer's weight/italic traits preserved, links
    /// tinted. Headings read as weight — same metrics, one voice, like the
    /// whisper in the editor.
    private static func attributedPage(html: String, fontSize: CGFloat, paragraph: NSParagraphStyle) -> NSAttributedString {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        let imported: NSAttributedString
        if let data = html.data(using: .utf8),
           let parsed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            imported = parsed
        } else {
            // Unparseable HTML — show the source text rather than nothing.
            imported = NSAttributedString(string: html)
        }

        let page = NSMutableAttributedString(attributedString: imported)
        let full = NSRange(location: 0, length: page.length)
        page.addAttribute(.paragraphStyle, value: paragraph, range: full)
        page.addAttribute(.foregroundColor, value: NSColor.textColor, range: full)

        page.enumerateAttribute(.font, in: full) { value, range, _ in
            guard let font = value as? NSFont else { return }
            let traits = font.fontDescriptor.symbolicTraits
            let weight: NSFont.Weight = traits.contains(.bold) ? .semibold : .regular
            var descriptor = EditorTypography.nsFont(size: fontSize, weight: weight).fontDescriptor
            if traits.contains(.italic) {
                descriptor = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.italic))
            }
            if let remapped = NSFont(descriptor: descriptor, size: fontSize) {
                page.addAttribute(.font, value: remapped, range: range)
            }
        }
        page.enumerateAttribute(.link, in: full) { _, range, _ in
            page.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
            page.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        return page
    }

    private static func contentKey(html: String?, needsOliver: Bool) -> String {
        html ?? (needsOliver ? "∅needsOliver" : "∅pending")
    }
}

/// Holds the last rendered content so updateNSView can no-op cheaply.
@MainActor
final class Coordinator: NSObject, NSTextViewDelegate {
    var lastKey: String?
    weak var textView: NSTextView?
}
