import AppKit
import BANALCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var autoCollapsedSidebar = false

    private static let sidebarCollapseWidth: CGFloat = 880
    private static let sidebarExpandWidth: CGFloat = 920

    var body: some View {
        Group {
            if model.needsVault {
                VaultPicker(model: model)
            } else {
                VStack(spacing: 0) {
                    NavigationSplitView(columnVisibility: $columnVisibility) {
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
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { updateSidebarCollapse(width: geo.size.width) }
                            .onChange(of: geo.size.width) { _, newWidth in
                                updateSidebarCollapse(width: newWidth)
                            }
                    }
                )
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

    private func updateSidebarCollapse(width: CGFloat) {
        if width < Self.sidebarCollapseWidth {
            guard !autoCollapsedSidebar, columnVisibility == .all else { return }
            columnVisibility = .doubleColumn
            autoCollapsedSidebar = true
        } else if width >= Self.sidebarExpandWidth {
            guard autoCollapsedSidebar else { return }
            columnVisibility = .all
            autoCollapsedSidebar = false
        }
    }
}

struct VaultPicker: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                VStack(spacing: 6) {
                    Text("BANAL")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(model.missingNotesFolder
                         ? "This notes folder is missing."
                         : "Notes are plain files in a folder you own.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
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
                    Button(useDefaultTitle) {
                        useDefaultFolder()
                    }
                    .keyboardShortcut(model.missingNotesFolder ? nil : .defaultAction)
                    .accessibilityLabel(useDefaultTitle)
                    Button("Choose…") {
                        if let url = NotesFolderPicker.run() {
                            model.openVault(url)
                        }
                    }
                    .keyboardShortcut(model.missingNotesFolder ? .defaultAction : nil)
                    .accessibilityLabel("Choose…")
                }
            }
            .padding(.horizontal, 40)
            Spacer()
            Text("Any folder works. Move it, sync it, back it up — the files are yours.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.missingNotesFolder ? "This notes folder is missing." : "Choose a notes folder.")
    }

    private let useDefaultTitle = "Use Documents/BANAL Notes"

    private var appIcon: NSImage {
        NSApp.applicationIconImage
    }

    private func useDefaultFolder() {
        let url = VaultBookmark.defaultVaultURL()
        // Seed only when we just created the folder ourselves. An existing
        // folder — even an empty one the user made earlier, or a trashed
        // welcome note left behind — is never touched again.
        let created = !FileManager.default.fileExists(atPath: url.path)
        if let allowed = VaultBookmark.createFolderIfAllowed(url) {
            if created {
                VaultSeed.seedWelcomeIfNeeded(in: allowed)
            }
            model.openVault(allowed, thenSelect: created ? VaultSeed.welcomeFileName : nil)
            return
        }
        // Sandboxed: the powerbox decides. A folder the user just chose in
        // a first-run moment gets the welcome note only when it holds no
        // notes at all — the guards in VaultSeed do the rest.
        guard let picked = NotesFolderPicker.run(
            startingAt: url.deletingLastPathComponent(),
            message: "Your notes will be plain files in this folder."
        ) else { return }
        let seeded = VaultSeed.seedWelcomeIfNeeded(in: picked)
        model.openVault(picked, thenSelect: seeded ? VaultSeed.welcomeFileName : nil)
    }
}
