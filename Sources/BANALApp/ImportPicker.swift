import AppKit
import Foundation

@MainActor
public enum ImportPicker {
    public static func run() -> [URL]? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = "Import"
        panel.title = "Import Notes and Folders"
        panel.message = "Choose note files (.md, .textile, .cook, .txt) or folders to copy into BANAL."
        guard panel.runModal() == .OK else { return nil }
        return panel.urls
    }
}
