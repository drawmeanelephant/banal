import BANALCore
import SwiftUI

public struct EditCommands: Commands {
    @FocusedObject private var focusedModel: AppModel?
    private var fallbackModel: AppModel

    private var model: AppModel {
        focusedModel ?? fallbackModel
    }

    public init(model: AppModel) {
        self.fallbackModel = model
    }

    public var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Menu("Copy As") {
                Button("Copy as Markdown") {
                    model.copyAs(.markdown)
                }
                .keyboardShortcut("c", modifiers: [.option, .shift, .command])
                .disabled(!model.canCopyAs)

                Button("Copy as Rich Text") {
                    model.copyAs(.richText)
                }
                .keyboardShortcut("c", modifiers: [.option, .command])
                .disabled(!model.canCopyAs)

                Button("Copy as HTML") {
                    model.copyAs(.html)
                }
                .disabled(!model.canCopyAs)
            }

            Divider()

            Button("Insert Photo…") {
                model.insertPhoto()
            }
            .disabled(!model.canInsertPhoto)

            Button("Insert Contact…") {
                model.insertContact()
            }
            .disabled(model.needsVault || model.selectedID == nil || model.viewMode != .edit)

            Button("Insert File…") {
                model.insertFile()
            }
            .disabled(model.needsVault || model.selectedID == nil || model.viewMode != .edit)

            Divider()

            Button("Translate…") {
                model.translateSelection()
            }
            .disabled(!model.canTranslate)

            Divider()

            Button("Enrich Markup") {
                model.enrichMarkup()
            }
            .disabled(model.needsVault || model.selectedID == nil || model.editorText.isEmpty)

            Button("Suggest Title") {
                model.suggestTitle()
            }
            .disabled(model.needsVault || model.selectedID == nil || model.editorText.isEmpty)
        }
    }
}
