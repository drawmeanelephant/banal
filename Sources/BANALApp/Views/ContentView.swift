import AppKit
import BANALCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            if model.needsVault {
                VaultPicker(model: model)
            } else {
                VStack(spacing: 0) {
                    NavigationSplitView {
                        SidebarView(model: model)
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Folders")
                    } content: {
                        NoteListView(model: model)
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Notes")
                    } detail: {
                        EditorView(model: model)
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Note")
                    }
                    .navigationSplitViewStyle(.balanced)

                    StatusStripView(model: model)
                }
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: model.statusMessage)
        .onChange(of: model.statusMessage) { _, new in
            if new != nil { model.dismissStatusLater() }
        }
        .onAppear {
            if !model.needsVault {
                model.bootstrap()
            }
        }
        .onDisappear { model.flushEditor() }
    }
}

struct VaultPicker: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Text(model.missingNotesFolder ? "This notes folder is missing." : "Choose a notes folder.")
                .font(.body)
                .foregroundStyle(.secondary)
            if model.missingNotesFolder {
                Text(model.store.configuration.rootURL.path)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 360)
                    .accessibilityLabel(model.store.configuration.rootURL.path)
            }
            HStack(spacing: 10) {
                Button("Documents/BANAL Notes") {
                    let url = VaultBookmark.defaultVaultURL()
                    if let allowed = VaultBookmark.createFolderIfAllowed(url) {
                        model.openVault(allowed)
                    } else if let picked = NotesFolderPicker.run(startingAt: url.deletingLastPathComponent()) {
                        model.openVault(picked)
                    }
                }
                .accessibilityLabel("Documents/BANAL Notes")
                Button("Choose…") {
                    if let url = NotesFolderPicker.run() {
                        model.openVault(url)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Choose…")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.missingNotesFolder ? "This notes folder is missing." : "Choose a notes folder.")
    }
}
