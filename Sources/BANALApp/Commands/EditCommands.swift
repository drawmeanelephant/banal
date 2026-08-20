import BANALCore
import SwiftUI

public struct EditCommands: Commands {
    @ObservedObject var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Translate…") {
                model.translateSelection()
            }
            .disabled(!model.canTranslate)
        }
    }
}
