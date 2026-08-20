import AppKit
import BANALCore
import Foundation

/// Coordinates native macOS share sheet presentation for notes.
@MainActor
public enum NoteShareCoordinator {

    /// Presents `NSSharingServicePicker` anchored to the specified view or window content.
    public static func shareNote(_ note: Note, from view: NSView? = nil, window: NSWindow? = nil) {
        let items = NoteSharePayload.items(for: note)
        guard !items.isEmpty else { return }

        let picker = NSSharingServicePicker(items: items)
        let targetWindow = window ?? NSApp.keyWindow ?? NSApp.mainWindow
        let targetView = view ?? targetWindow?.contentView

        guard let targetView else { return }
        let rect = NSRect(
            x: targetView.bounds.midX,
            y: targetView.bounds.midY,
            width: 0,
            height: 0
        )
        picker.show(relativeTo: rect, of: targetView, preferredEdge: .minY)
    }
}
