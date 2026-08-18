import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if model.needsVault {
                VaultPicker(model: model)
            } else {
                NavigationSplitView {
                    SidebarView(model: model)
                } content: {
                    NoteListView(model: model)
                } detail: {
                    EditorView(model: model)
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .overlay(alignment: .bottom) {
            if let status = model.statusMessage {
                Text(status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .overlay(alignment: .top) {
                        Divider()
                    }
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
                    .onTapGesture { model.statusMessage = nil }
            }
        }
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
            }
            HStack(spacing: 10) {
                Button("Documents/BANAL Notes") {
                    let url = VaultBookmark.defaultVaultURL()
                    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    model.openVault(url)
                }
                Button("Choose…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.canCreateDirectories = true
                    panel.prompt = "Use Folder"
                    if panel.runModal() == .OK, let url = panel.url {
                        model.openVault(url)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
