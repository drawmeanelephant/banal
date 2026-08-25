import BANALAppModel
import BANALCore
import Combine
import Foundation

/// A real store over a throwaway vault, plus a recipe context that
/// records what the session asked for.
@MainActor
final class ControllerContext: RecipeContext {
    let store: NoteStore
    private(set) var statuses: [String] = []
    private(set) var cachedIngredientCalls: [(names: [String], noteID: String)] = []

    var stubSelectedID: String?
    var stubViewMode: ViewMode = .edit

    init(vault: VaultConfiguration) {
        store = NoteStore(configuration: vault, monitor: nil)
        try? store.open()
    }

    var selectedID: String? { stubSelectedID }
    var selectedNote: Note? { selectedID.flatMap { store.note(id: $0) } }
    var viewMode: ViewMode { stubViewMode }
    var bufferText: String { "" }

    func cacheIngredients(_ names: [String], forNoteID noteID: String) {
        cachedIngredientCalls.append((names, noteID))
    }

    func showStatus(_ message: String) {
        statuses.append(message)
    }
}

@MainActor
enum TestVault {
    static func make() throws -> VaultConfiguration {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("banal-controllers-\(UUID().uuidString)", isDirectory: true)
        let configuration = VaultConfiguration(rootURL: root)
        try VaultBootstrap.prepare(configuration)
        return configuration
    }
}
