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
                .accessibilityLabel("Create a note with ⌘N.")
        } else {
            VStack(spacing: 0) {
                titleField
                    .frame(maxWidth: measure)
                    .frame(maxWidth: .infinity)
                metadataRow
                    .frame(maxWidth: measure)
                    .frame(maxWidth: .infinity)
                if model.showsRecipeSwitcher, model.recipeMode == .read {
                    RecipeReadView(model: model)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    MarkdownTextView(
                        text: $model.editorText,
                        documentID: model.selectedID ?? "",
                        findToken: model.findInNoteToken,
                        focusToken: model.editorFocus,
                        style: EditorStyle(from: model.preferences)
                    )
                    .onChange(of: model.editorText) { _, _ in
                        model.applyEditorChanges()
                    }
                    .frame(maxWidth: measure)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
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
            .accessibilityLabel("Title")
            .onChange(of: model.editorTitle) { _, _ in
                model.applyEditorChanges()
            }
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if let note = model.selectedNote {
                    Text(note.updated, format: .relative(presentation: .named))
                }
                if model.editorPublished {
                    Text("·")
                        .accessibilityHidden(true)
                    Image(systemName: "globe")
                        .accessibilityHidden(true)
                    Text("Published")
                }
                if !visibleTags.isEmpty {
                    Text("·")
                        .accessibilityHidden(true)
                    Text(visibleTags)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            if model.showsRecipeSwitcher {
                Picker("Recipe view", selection: Binding(
                    get: { model.recipeMode },
                    set: { model.setRecipeMode($0) }
                )) {
                    Text("Edit").tag(RecipeMode.edit)
                    Text("Read").tag(RecipeMode.read)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(maxWidth: 140)
                .labelsHidden()
                .accessibilityLabel("Recipe view")
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
