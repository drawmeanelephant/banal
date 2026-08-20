import BANALCore
import SwiftUI

public struct FileCommands: Commands {
    @ObservedObject var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some Commands {
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
