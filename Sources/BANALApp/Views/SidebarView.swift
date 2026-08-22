import AppKit
import BANALCore
import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        List(selection: selectionBinding) {
            Label("All Notes", systemImage: "square.stack")
                .tag(SidebarFilter.all)
                .accessibilityLabel("All Notes")
                .accessibilityValue(AccessibilityFormatting.noteCount(model.store.notes.count))
                .accessibilityHint("Shows all notes in the vault")
                .dropDestination(for: URL.self) { urls, _ in
                    urls.forEach { model.dropNote(with: $0, onto: nil) }
                    return true
                }

            Label("Published", systemImage: "globe")
                .tag(SidebarFilter.published)
                .accessibilityLabel("Published")
                .accessibilityValue(AccessibilityFormatting.publishedNoteCount(model.store.notes.filter(\.published).count))
                .accessibilityHint("Shows notes marked for publishing")

            if !model.store.folderTree.isEmpty {
                Section {
                    OutlineGroup(model.store.folderTree, children: \.outlineChildren) { node in
                        let count = model.store.notes.filter { $0.folder == node.id }.count
                        let isVanished = model.store.vanishedFolderPaths.contains(node.id)
                        Label {
                            HStack(spacing: 4) {
                                Text(node.name)
                                if isVanished {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel("Moved or renamed in Finder")
                                }
                            }
                        } icon: {
                            Image(systemName: isVanished ? "folder.badge.questionmark" : "folder")
                        }
                        .tag(SidebarFilter.folder(node.id))
                        .accessibilityLabel(isVanished ? "\(node.name), moved or renamed" : node.name)
                        .accessibilityValue(AccessibilityFormatting.folderNoteCount(count))
                        .accessibilityHint(isVanished ? "Folder was moved or renamed in Finder" : "Folder")
                            .dropDestination(for: URL.self) { urls, _ in
                                urls.forEach { model.dropNote(with: $0, onto: node.id) }
                                return true
                            }
                            .contextMenu {
                                Button("New Note Here") {
                                    model.createNote(in: node.id)
                                }
                                Button("New Folder") {
                                    model.filter = .folder(node.id)
                                    model.beginNewFolder()
                                }
                                Button("Rename…") {
                                    model.beginRenameFolder(node.id)
                                }
                                Divider()
                                Button("Move to Trash", role: .destructive) {
                                    model.filter = .folder(node.id)
                                    model.trashSelectedFolder()
                                }
                            }
                    }
                }
            }

            if !model.store.tags.isEmpty {
                Section("Tags") {
                    ForEach(model.store.tags, id: \.self) { tag in
                        let count = model.store.notes.filter { $0.tags.contains(tag) }.count
                        Label("#\(tag)", systemImage: "number")
                            .tag(SidebarFilter.tag(tag))
                            .accessibilityLabel("Tag \(tag)")
                            .accessibilityValue(AccessibilityFormatting.noteCount(count))
                            .accessibilityHint("Filter notes by tag")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .background(SidebarFocusHelper(model: model))
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        .overlay(alignment: .trailing) {
            if contrast == .increased {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1)
            }
        }
        .contextMenu {
            Button("New Folder") { model.beginNewFolder() }
        }
        .alert("New Folder", isPresented: $model.isCreatingFolder) {
            TextField("Name", text: $model.folderNameDraft)
            Button("Create") { model.confirmNewFolder() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Folder", isPresented: $model.isRenamingFolder) {
            TextField("Name", text: $model.folderNameDraft)
            Button("Rename") { model.confirmRenameFolder() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var selectionBinding: Binding<SidebarFilter?> {
        Binding(
            get: { model.filter },
            set: { newFilter in
                guard let newFilter else {
                    model.filter = .all
                    return
                }
                if case .tag(let activeTag) = model.filter, case .tag(let clickedTag) = newFilter, activeTag == clickedTag {
                    model.filter = .all
                } else {
                    model.filter = newFilter
                }
            }
        )
    }
}

private struct SidebarFocusHelper: NSViewRepresentable {
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
        weak var outlineView: NSOutlineView?
        private var eventMonitor: Any?
        private weak var hostView: NSView?

        init(model: AppModel) {
            self.model = model
        }

        func setup(view: NSView) {
            self.hostView = view
            installFocusHandler()
            installMonitor()
            DispatchQueue.main.async { [weak self] in
                self?.attachIfNeeded()
            }
        }

        func installFocusHandler() {
            model?.sidebarFocus.handler = { [weak self] in
                self?.focus()
            }
        }

        func attachIfNeeded() {
            installFocusHandler()
            if outlineView == nil, let hostView {
                outlineView = findOutlineView(from: hostView)
            }
        }

        func focus() {
            attachIfNeeded()
            guard let outlineView, let window = outlineView.window else { return }
            window.makeFirstResponder(outlineView)
        }

        private func installMonitor() {
            guard eventMonitor == nil else { return }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self,
                      let outlineView = self.outlineView,
                      let window = outlineView.window,
                      window.firstResponder === outlineView else {
                    return event
                }
                if event.keyCode == 48 { // Tab
                    if event.modifierFlags.contains(.shift) {
                        self.model?.focusEditor()
                    } else {
                        self.model?.focusNoteList()
                    }
                    return nil
                }
                if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
                    self.model?.focusNoteList()
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
            model?.sidebarFocus.handler = nil
        }

        private func findOutlineView(from view: NSView) -> NSOutlineView? {
            var current: NSView? = view
            while let v = current {
                if let outline = v as? NSOutlineView { return outline }
                if let scroll = v as? NSScrollView, let outline = scroll.documentView as? NSOutlineView {
                    return outline
                }
                current = v.superview
            }
            if let parent = view.superview, let found = findOutlineViewInSubviews(of: parent) {
                return found
            }
            if let root = view.window?.contentView {
                return findOutlineViewInSubviews(of: root)
            }
            return nil
        }

        private func findOutlineViewInSubviews(of root: NSView) -> NSOutlineView? {
            if let outline = root as? NSOutlineView { return outline }
            if let scroll = root as? NSScrollView, let outline = scroll.documentView as? NSOutlineView {
                return outline
            }
            for subview in root.subviews {
                if let found = findOutlineViewInSubviews(of: subview) {
                    return found
                }
            }
            return nil
        }
    }
}
