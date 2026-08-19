import AppKit
import BANALCore
import SwiftUI

@main
struct BanalApp: App {
    @StateObject private var model: AppModel
    @NSApplicationDelegateAdaptor(BanalAppDelegate.self) private var appDelegate

    init() {
        let remembered = VaultBookmark.restore()
        let access = NotesFolderAccess.resolve(remembered: remembered)
        let root: URL
        let needsVault: Bool
        let missing: Bool
        switch access {
        case .ready(let url):
            root = url
            needsVault = false
            missing = false
        case .missing(let url):
            root = url
            needsVault = true
            missing = true
        case .firstRun:
            root = VaultBookmark.defaultVaultURL()
            needsVault = true
            missing = false
        }
        let store = NoteStore(configuration: VaultConfiguration(rootURL: root))
        _model = StateObject(wrappedValue: AppModel(
            store: store,
            needsVault: needsVault,
            missingNotesFolder: missing,
            preferences: AppPreferencesStore.load()
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onAppear {
                    appDelegate.model = model
                    appDelegate.flushPendingOpens()
                }
                .onOpenURL { url in
                    model.openExternalNote(at: url)
                }
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About BANAL") {
                    BanalAbout.show()
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    model.createNote()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(model.needsVault)

                Button("New Folder") {
                    model.beginNewFolder()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(model.needsVault)

                Button("New Textile") {
                    model.createNote(language: .textile)
                }
                .disabled(model.needsVault)

                Button("New Recipe") {
                    model.createNote(language: .cooklang)
                }
                .disabled(model.needsVault)

                Button("Move to Trash") {
                    if model.selectedID != nil {
                        model.trashSelected()
                    } else if model.selectedFolderPath != nil {
                        model.trashSelectedFolder()
                    }
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(model.needsVault || (model.selectedID == nil && model.selectedFolderPath == nil))

                Divider()

                Button("Open Notes Folder…") {
                    chooseVault()
                }

                Button("Reveal in Finder") {
                    model.revealSelected()
                }
                .disabled(model.needsVault || (model.selectedID == nil && model.selectedFolderPath == nil))

                Button("Reveal Notes Folder in Finder") {
                    model.revealVault()
                }
                .disabled(model.needsVault && model.missingNotesFolder)
            }

            CommandGroup(after: .newItem) {
                Button(model.editorPublished ? "Unpublish" : "Publish") {
                    model.togglePublished()
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                .disabled(model.needsVault || model.selectedID == nil)

                Button("Publish Site…") {
                    model.publishSite()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(model.needsVault)

                Button("Deploy to Cloudflare") {
                    model.deployToCloudflare()
                }
                .disabled(model.needsVault || !model.canDeploy)
            }

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

            CommandGroup(after: .toolbar) {
                Button("Edit Recipe") {
                    model.setRecipeMode(.edit)
                }
                .disabled(!model.showsRecipeSwitcher)

                Button("Read Recipe") {
                    model.setRecipeMode(.read)
                }
                .disabled(!model.showsRecipeSwitcher)
            }
        }

        Settings {
            SettingsRoot(model: model)
        }
    }

    private func chooseVault() {
        if let url = NotesFolderPicker.run() {
            model.openVault(url)
        }
    }
}

enum BanalAbout {
    static let applicationName = "BANAL"
    static let version = "0.1.0"
    static let mission = "BANAL is a beautiful, boring, local Mac notes app whose files are allowed to be excellent."

    @MainActor
    static func show() {
        let credits = NSMutableParagraphStyle()
        credits.alignment = .center
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: applicationName,
            .applicationVersion: version,
            .credits: NSAttributedString(
                string: mission,
                attributes: [
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                    .paragraphStyle: credits,
                    .foregroundColor: NSColor.labelColor,
                ]
            ),
        ])
    }
}

final class BanalAppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    /// Open-file events (Finder double-click, Dock drag) that arrived
    /// before ContentView handed us the model. Drained in
    /// `flushPendingOpens()`.
    private var pendingOpenURLs: [URL] = []

    /// A multi-file open (Finder multi-select → Open With, a Dock drag of
    /// several files) arrives as one Apple event. SwiftUI's `.onOpenURL`
    /// surfaces only the *first* URL; the rest reach this AppKit delegate
    /// hook, so without them a multi-select open was silently dropped.
    /// Implemented here (`open:` on the macOS 26 SDK, `openURLs:` before),
    /// routing the rest through the same queue as `.onOpenURL`. `AppModel`
    /// dedupes, so a single action can never import twice even when both
    /// routes fire.
    #if swift(>=6.4)
    func application(_ application: NSApplication, open urls: [URL]) {
        pendingOpenURLs.append(contentsOf: urls)
        flushPendingOpens()
    }
    #else
    func application(_ application: NSApplication, openURLs urls: [URL]) {
        pendingOpenURLs.append(contentsOf: urls)
        flushPendingOpens()
    }
    #endif

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        pendingOpenURLs.append(contentsOf: filenames.map { URL(fileURLWithPath: $0) })
        flushPendingOpens()
    }

    /// The model is set from `ContentView.onAppear`, which can race an
    /// open-file event during launch. Queue until then. Called only from
    /// MainActor contexts (the open-files delegate hook and `.onAppear`).
    @MainActor
    func flushPendingOpens() {
        guard !pendingOpenURLs.isEmpty else { return }
        let urls = pendingOpenURLs
        pendingOpenURLs.removeAll()
        for url in urls {
            model?.openExternalNote(at: url)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if ProcessInfo.processInfo.environment["BANAL_SMOKE_TEST"] != nil {
            // Startup smoke (Scripts/smoke.sh): give the window a beat to
            // appear, then wait until bootstrap() has written
            // .banal/config.json (or a deadline passes) before quitting
            // through the normal path, so applicationWillTerminate runs
            // and the exit status is 0. The script asserts the files on
            // disk independently — no race on slow machines.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.finishSmokeTest()
            }
        }
    }

    /// Quit the smoke-test instance once the vault has actually been
    /// opened. `bootstrap()` writes `.banal/config.json`; if that never
    /// happens (wrong BANAL_VAULT, sandbox-blocked path), quit at the
    /// deadline and let the script report the failure.
    /// When `BANAL_SMOKE_OPEN_FILE` is set (the open-event case, comma-
    /// separated for multiple files), also wait until every leaf exists in
    /// the vault — the script delivers the files via LaunchServices after
    /// launch, and all imports must land before the app quits, or the test
    /// would false-pass.
    @MainActor
    private func finishSmokeTest() {
        let deadline = Date().addingTimeInterval(10)
        let openLeaves = ProcessInfo.processInfo.environment["BANAL_SMOKE_OPEN_FILE"]?
            .split(separator: ",")
            .map(String.init)
            .filter { !$0.isEmpty } ?? []
        func poll() {
            let configURL = model?.store.configuration.configURL
            let opened = configURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            var missing: [String] = []
            if let rootURL = model?.store.configuration.rootURL {
                for leaf in openLeaves where !FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(leaf).path) {
                    missing.append(leaf)
                }
            }
            if opened && missing.isEmpty {
                print("BANAL smoke: ready")
                NSApp.terminate(nil)
                return
            }
            if Date() >= deadline {
                let what = opened ? "the open-file import(s) never landed: \(missing.joined(separator: ", "))" : "the vault to open"
                print("BANAL smoke: timed out waiting for \(what)")
                NSApp.terminate(nil)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: poll)
        }
        poll()
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            model?.flushEditor()
            VaultBookmark.endAccess()
            SecurityScope.stopAll()
        }
    }
}
