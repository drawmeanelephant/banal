import BANALCore
import SwiftUI

public struct FileCommands: Commands {
    @FocusedObject private var focusedModel: AppModel?
    private var fallbackModel: AppModel
    @Environment(\.openWindow) private var openWindow

    private var model: AppModel {
        focusedModel ?? fallbackModel
    }

    public init(model: AppModel) {
        self.fallbackModel = model
    }

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                model.createNote()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(model.needsVault)

            Button("New Window") {
                openWindow(id: "main-window")
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
            .disabled(model.needsVault)

            Button("New Folder") {
                model.beginNewFolder()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(model.needsVault)

            Button("New Textile") {
                model.createNote(language: .textile)
            }
            .disabled(model.needsVault)

            Button("New Recipe") {
                model.createNote(language: .cooklang)
            }
            .disabled(model.needsVault)

            Button("Move to Trash") {
                if model.selectedID != nil {
                    model.trashSelected()
                } else if model.selectedFolderPath != nil {
                    model.trashSelectedFolder()
                }
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(model.needsVault || (model.selectedID == nil && model.selectedFolderPath == nil))

            Divider()

            Button("Open Notes Folder…") {
                if let url = NotesFolderPicker.run() {
                    model.openVault(url)
                }
            }

            Button("Reveal in Finder") {
                model.revealSelected()
            }
            .disabled(model.needsVault || (model.selectedID == nil && model.selectedFolderPath == nil))

            Button("Reveal Notes Folder in Finder") {
                model.revealVault()
            }
            .disabled(model.needsVault && model.missingNotesFolder)
        }

        CommandGroup(after: .newItem) {
            Button(model.editorPublished ? "Unpublish" : "Publish") {
                model.togglePublished()
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
            .disabled(model.needsVault || model.selectedID == nil)

            Button("Publish Site…") {
                model.publishSite()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(model.needsVault)

            Button("Deploy to Cloudflare") {
                model.deployToCloudflare()
            }
            .disabled(model.needsVault || !model.canDeploy)

            Divider()

            Button("Save Scaled Copy…") {
                model.saveScaledCopy()
            }
            .disabled(model.needsVault || model.selectedID == nil || model.selectedNote?.language != .cooklang || model.recipeScale == .one)
        }

        CommandGroup(replacing: .printItem) {
            Button("Print…") {
                model.printSelectedNote()
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(model.needsVault || model.selectedID == nil)
        }

        CommandGroup(replacing: .importExport) {
            Button("Import…") {
                model.presentImportPanel()
            }
            .keyboardShortcut("i", modifiers: .command)
            .disabled(model.needsVault)

            Divider()

            Button("Share…") {
                model.shareSelectedNote()
            }
            .disabled(model.needsVault || model.selectedID == nil)
        }
    }
}
