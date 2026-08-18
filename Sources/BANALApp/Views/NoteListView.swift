import BANALCore
import SwiftUI

struct NoteListView: View {
    @ObservedObject var model: AppModel
    @FocusState private var searchFieldFocused: Bool
    @State private var searchVisible = false

    private var showSearch: Bool {
        searchVisible || searchFieldFocused || !model.searchQuery.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if showSearch {
                searchField
            }

            if model.visibleNotes.isEmpty {
                emptyState
            } else {
                List(model.visibleNotes, selection: model.listSelection) { note in
                    NoteRow(note: note)
                        .tag(note.id)
                        .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
                        .listRowSeparatorTint(Color(nsColor: .separatorColor))
                        .draggable(note.id)
                        .contextMenu {
                            Button(note.published ? "Unpublish" : "Publish") {
                                model.select(note.id)
                                model.togglePublished()
                            }
                            Button("Move to Trash", role: .destructive) {
                                model.select(note.id)
                                model.trashSelected()
                            }
                        }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .navigationTitle(title)
        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        .onChange(of: model.searchFocusToken) { _, _ in
            searchVisible = true
            searchFieldFocused = true
        }
        .onChange(of: searchFieldFocused) { _, focused in
            if !focused, model.searchQuery.isEmpty {
                searchVisible = false
            }
        }
        .onExitCommand {
            if showSearch {
                model.searchQuery = ""
                searchFieldFocused = false
                searchVisible = false
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            TextField("Search", text: $model.searchQuery)
                .textFieldStyle(.plain)
                .focused($searchFieldFocused)
                .onSubmit { searchFieldFocused = false }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var title: String {
        switch model.filter {
        case .all: return "Notes"
        case .published: return "Published"
        case .tag(let tag): return tag
        case .folder(let folder): return (folder as NSString).lastPathComponent
        }
    }

    private var emptyState: some View {
        Text(emptyTitle)
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(emptyTitle)
    }

    private var emptyTitle: String {
        if !model.searchQuery.isEmpty { return "No notes match." }
        if case .folder = model.filter { return "No notes in this folder." }
        if case .published = model.filter { return "Nothing published." }
        return "Create a note with ⌘N."
    }
}

private struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(note.displayTitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if note.published {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Published")
                }
                Spacer(minLength: 8)
                Text(note.updated, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .layoutPriority(1)
            }
            Text(note.snippet.isEmpty ? " " : note.snippet)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 1)
        .accessibilityElement(children: .combine)
    }
}
