import AppKit
import BANALCore

@MainActor
public enum FilePickerPresenter {
    public static func present(
        in window: NSWindow? = nil,
        vaultURL: URL,
        linkTitle: String? = nil,
        onSelect: @escaping (String) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.title = "Insert File"
        panel.prompt = "Insert"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true

        let handleSelection: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let record = try AssetManager.storeAsset(from: url, in: vaultURL)
                let title = (linkTitle != nil && !linkTitle!.isEmpty) ? linkTitle : record.originalFilename
                let link = AssetManager.fileLink(name: title, relativePath: record.relativePath)
                onSelect(link)
            } catch {
                NSSound.beep()
            }
        }

        if let window {
            panel.beginSheetModal(for: window, completionHandler: handleSelection)
        } else {
            let response = panel.runModal()
            handleSelection(response)
        }
    }
}
