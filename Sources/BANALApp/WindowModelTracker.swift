import SwiftUI

/// The most recent notes-window model. Menu commands resolve through it
/// when no window exposing a focused object is key — the Settings scene,
/// or after the last main window closed (#191). Strong on purpose: with
/// the window gone but a vault open, New Note / New Window still work.
@MainActor
final class WindowModelTracker: ObservableObject {
    static let shared = WindowModelTracker()

    @Published private(set) var latest: AppModel?

    private init() {}

    func activate(_ model: AppModel) {
        latest = model
    }
}
