import AppKit
import Foundation

@MainActor
enum NotesFolderPicker {
    static func run(startingAt directory: URL? = nil, message: String? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Use Folder"
        if let message {
            panel.message = message
        }
        if let directory {
            panel.directoryURL = directory
        }
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
