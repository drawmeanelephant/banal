import AppKit
import BANALCore
import SwiftUI

struct NoteListView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField

            if model.visibleNotes.isEmpty {
                emptyState
            } else {
                List(model.visibleNotes, selection: model.listSelection) { note in
                    NoteRow(note: note)
                        .tag(note.id)
                        .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
                        .listRowSeparatorTint(Color(nsColor: .separatorColor))
                        .onDrag {
                            NoteDragProvider.itemProvider(for: note)
                        }
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
        .background(NoteListFocusHelper(model: model))
        .navigationTitle(title)
        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        .overlay(alignment: .trailing) {
            if contrast == .increased {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1)
            }
        }
        .onChange(of: model.searchFocusToken) { _, _ in
            searchFieldFocused = true
        }
        .onExitCommand {
            if searchFieldFocused || !model.searchQuery.isEmpty {
                model.searchQuery = ""
                searchFieldFocused = false
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
                .accessibilityLabel("Search notes")
                .accessibilityHint("Filter notes by title, body, tags, or ingredients")
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
        case .tag(let tag): return "#\(tag)"
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
        if case .tag = model.filter { return "No notes with this tag." }
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
                if note.language == .cooklang {
                    Image(systemName: "fork.knife")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("Recipe")
                }
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
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Select note to view or edit")
    }

    private var accessibilityLabel: String {
        AccessibilityFormatting.noteRowDescription(
            title: note.displayTitle,
            folder: note.folder,
            isRecipe: note.language == .cooklang,
            isPublished: note.published,
            updatedDate: note.updated,
            snippet: note.snippet
        )
    }
}

private struct NoteListFocusHelper: NSViewRepresentable {
    @ObservedObject var model: AppModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.setup(view: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.model = model
        context.coordinator.attachIfNeeded()
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var model: AppModel?
        weak var tableView: NSTableView?
        private var eventMonitor: Any?
        private weak var hostView: NSView?

        init(model: AppModel) {
            self.model = model
        }

        func setup(view: NSView) {
            self.hostView = view
            installFocusHandler()
            installQuickLookHandler()
            installMonitor()
            DispatchQueue.main.async { [weak self] in
                self?.attachIfNeeded()
            }
        }

        func installFocusHandler() {
            model?.noteListFocus.handler = { [weak self] in
                self?.focus()
            }
        }

        func installQuickLookHandler() {
            model?.quickLook.handler = { [weak self] in
                self?.toggleQuickLook()
            }
        }

        func attachIfNeeded() {
            installFocusHandler()
            installQuickLookHandler()
            if tableView == nil, let hostView {
                tableView = findTableView(from: hostView)
            }
        }

        func focus() {
            attachIfNeeded()
            guard let tableView, let window = tableView.window else { return }
            if let selectedID = model?.selectedID,
               let index = model?.visibleNotes.firstIndex(where: { $0.id == selectedID }) {
                tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                tableView.scrollRowToVisible(index)
            }
            window.makeFirstResponder(tableView)
        }

        func toggleQuickLook() {
            guard let note = model?.selectedNote else { return }
            NSWorkspace.shared.open(note.fileURL)
        }

        private func installMonitor() {
            guard eventMonitor == nil else { return }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self,
                      let tableView = self.tableView,
                      let window = tableView.window,
                      window.firstResponder === tableView else {
                    return event
                }
                if event.keyCode == 49 { // Space
                    if event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
                        self.toggleQuickLook()
                        return nil
                    }
                }
                if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
                    self.model?.focusEditor()
                    return nil
                }
                if event.keyCode == 48 { // Tab
                    if event.modifierFlags.contains(.shift) {
                        self.model?.focusSidebar()
                    } else {
                        self.model?.focusEditor()
                    }
                    return nil
                }
                return event
            }
        }

        func teardown() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
                self.eventMonitor = nil
            }
            model?.noteListFocus.handler = nil
            model?.quickLook.handler = nil
        }

        private func findTableView(from view: NSView) -> NSTableView? {
            var current: NSView? = view
            while let v = current {
                if let table = v as? NSTableView { return table }
                if let scroll = v as? NSScrollView, let table = scroll.documentView as? NSTableView {
                    return table
                }
                current = v.superview
            }
            if let parent = view.superview, let found = findTableViewInSubviews(of: parent) {
                return found
            }
            if let root = view.window?.contentView {
                return findTableViewInSubviews(of: root)
            }
            return nil
        }

        private func findTableViewInSubviews(of root: NSView) -> NSTableView? {
            if let table = root as? NSTableView { return table }
            if let scroll = root as? NSScrollView, let table = scroll.documentView as? NSTableView {
                return table
            }
            for subview in root.subviews {
                if let found = findTableViewInSubviews(of: subview) {
                    return found
                }
            }
            return nil
        }
    }
}
