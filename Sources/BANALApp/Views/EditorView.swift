#if canImport(Translation)
import Translation
#endif
import BANALCore
import SwiftUI

struct EditorView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.selectedNote == nil {
            Text("Create a note with ⌘N.")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
                .accessibilityLabel("No note selected. Create a note with ⌘N.")
        } else {
            VStack(spacing: 0) {
                titleField
                    .frame(maxWidth: measure)
                    .frame(maxWidth: .infinity)
                metadataRow
                    .frame(maxWidth: measure)
                    .frame(maxWidth: .infinity)
                if model.showsViewSwitcher, model.viewMode == .read {
                    Group {
                        if model.selectedNote?.language == .cooklang {
                            RecipeReadView(model: model)
                        } else {
                            ProseReadView(
                                html: model.lastOliverRender?.html,
                                needsOliver: !model.oliverCanRender,
                                style: EditorStyle(from: model.preferences)
                            )
                        }
                    }
                    .frame(maxWidth: measure)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    MarkdownTextView(
                        text: $model.editorText,
                        documentID: model.editorSessionID.uuidString,
                        language: model.selectedNote?.language ?? .markdown,
                        findToken: model.findInNoteToken,
                        focusToken: model.editorFocus,
                        style: EditorStyle(from: model.preferences),
                        onEscape: { [weak model] in model?.focusNoteList() },
                        onTab: { [weak model] in model?.focusSidebar() },
                        onBacktab: { [weak model] in model?.focusNoteList() },
                        onWritingToolsActiveChange: { [weak model] active in
                            model?.isWritingToolsActive = active
                        },
                        onSelectionChange: { [weak model] selected, range in
                            model?.selectedText = selected
                            model?.selectedRange = range
                        },
                        onTranslate: { [weak model] text, range in
                            model?.selectedText = text
                            model?.selectedRange = range
                            model?.translateSelection()
                        }
                    )
                    .onChange(of: model.editorText) { _, _ in
                        model.applyEditorChanges()
                    }
                    .frame(maxWidth: measure)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .modifier(TranslationPresentationModifier(model: model))
            .onChange(of: model.viewMode) { _, newMode in
                // The gate: hit Edit and the caret is back in the Markdown.
                // Defer past the SwiftUI commit so the fresh editor exists
                // and its focus handler is installed before we ask.
                if newMode == .edit {
                    DispatchQueue.main.async {
                        model.editorFocus.request()
                    }
                }
            }
        }
    }

    private var measure: CGFloat? {
        model.preferences.limitLineLength ? EditorTypography.measureWidth : nil
    }

    private var titleField: some View {
        TextField("Title", text: $model.editorTitle)
            .textFieldStyle(.plain)
            .font(EditorTypography.swiftUIFont(
                size: EditorTypography.titleSize,
                weight: .semibold
            ))
            .foregroundStyle(Color(nsColor: .textColor))
            .padding(.horizontal, EditorTypography.horizontalInset)
            .padding(.top, 36)
            .padding(.bottom, 6)
            .accessibilityLabel("Note title")
            .accessibilityHint("Edit note title")
            .onChange(of: model.editorTitle) { _, _ in
                model.applyEditorChanges()
            }
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if let note = model.selectedNote {
                    Text(note.updated, format: .relative(presentation: .named))
                        .accessibilityLabel("Updated \(note.updated.formatted(.relative(presentation: .named)))")
                }
                if model.editorPublished {
                    Text("·")
                        .accessibilityHidden(true)
                    Image(systemName: "globe")
                        .accessibilityHidden(true)
                    Text("Published")
                        .accessibilityLabel("Published note")
                }
                if !visibleTags.isEmpty {
                    Text("·")
                        .accessibilityHidden(true)
                    Text(visibleTags)
                        .lineLimit(1)
                        .accessibilityLabel("Tags: \(visibleTags)")
                }
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            if model.showsViewSwitcher {
                Picker("Note view", selection: Binding(
                    get: { model.viewMode },
                    set: { model.setViewMode($0) }
                )) {
                    Text("Edit").tag(ViewMode.edit)
                    Text("Read").tag(ViewMode.read)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(maxWidth: 140)
                .labelsHidden()
                .accessibilityLabel("Note view mode")
                .accessibilityHint("Switch between edit and read modes")
            }
        }
        .padding(.horizontal, EditorTypography.horizontalInset)
        .padding(.bottom, 8)
    }

    private var visibleTags: String {
        model.editorTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}


struct TranslationPresentationModifier: ViewModifier {
    @ObservedObject var model: AppModel

    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(macOS 15.0, *) {
            content
                .translationPresentation(
                    isPresented: $model.isTranslationPresented,
                    text: model.translationText
                ) { translated in
                    model.replaceSelectedText(with: translated)
                }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
