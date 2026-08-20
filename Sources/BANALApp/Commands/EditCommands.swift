import BANALCore
import SwiftUI

public struct EditCommands: Commands {
    @ObservedObject var model: AppModel

    public init(model: AppModel) {
        self.model = model
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

            Button("Translate…") {
                model.translateSelection()
            }
            .disabled(!model.canTranslate)
        }
    }
}
