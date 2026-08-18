import BANALCore
import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        List(selection: $model.filter) {
            Label("All Notes", systemImage: "square.stack")
                .tag(SidebarFilter.all)
                .dropDestination(for: String.self) { ids, _ in
                    ids.forEach { model.dropNote($0, onto: nil) }
                    return true
                }

            Label("Published", systemImage: "globe")
                .tag(SidebarFilter.published)

            if !model.store.folderTree.isEmpty {
                Section {
                    OutlineGroup(model.store.folderTree, children: \.outlineChildren) { node in
                        Label(node.name, systemImage: "folder")
                            .tag(SidebarFilter.folder(node.id))
                            .dropDestination(for: String.self) { ids, _ in
                                ids.forEach { model.dropNote($0, onto: node.id) }
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
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
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
}
