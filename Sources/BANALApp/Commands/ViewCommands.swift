import BANALCore
import SwiftUI

public struct ViewCommands: Commands {
    @FocusedObject private var focusedModel: AppModel?
    @ObservedObject private var trackedModels = WindowModelTracker.shared
    private var fallbackModel: AppModel

    private var model: AppModel {
        focusedModel ?? trackedModels.latest ?? fallbackModel
    }

    public init(model: AppModel) {
        self.fallbackModel = model
    }

    public var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Focus Sidebar") {
                model.focusSidebar()
            }
            .keyboardShortcut("1", modifiers: .command)
            .disabled(model.needsVault)

            Button("Focus Note List") {
                model.focusNoteList()
            }
            .keyboardShortcut("2", modifiers: .command)
            .disabled(model.needsVault)

            Button("Focus Editor") {
                model.focusEditor()
            }
            .keyboardShortcut("3", modifiers: .command)
            .disabled(model.needsVault || model.selectedID == nil)

            Divider()

            Button("Edit Note") {
                model.setViewMode(.edit)
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(model.selectedID == nil)

            Button("Read Note") {
                model.setViewMode(.read)
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(model.selectedID == nil)

            Divider()

            Button("Quick Look Note") {
                model.toggleQuickLook()
            }
            .keyboardShortcut("y", modifiers: .command)
            .disabled(model.selectedID == nil)
        }
    }
}
