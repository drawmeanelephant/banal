import BANALCore
import SwiftUI

public struct FindCommands: Commands {
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
        // Move Find Notes and Find in Note into the Edit menu via
        // CommandGroup so we don't duplicate the system Find menu.
        CommandGroup(replacing: .textEditing) {
            Button("Find Notes") {
                model.focusSearch()
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(model.needsVault)

            Button("Find in Note") {
                model.findInNote()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(model.needsVault || model.selectedID == nil)
        }
    }
}
