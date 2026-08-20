import BANALCore
import SwiftUI

public struct FindCommands: Commands {
    @FocusedObject private var focusedModel: AppModel?
    private var fallbackModel: AppModel

    private var model: AppModel {
        focusedModel ?? fallbackModel
    }

    public init(model: AppModel) {
        self.fallbackModel = model
    }

    public var body: some Commands {
        CommandMenu("Find") {
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
