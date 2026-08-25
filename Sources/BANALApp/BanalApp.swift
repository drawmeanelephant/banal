import AppKit
import BANALCore
import CoreSpotlight
import SwiftUI

@main
struct BanalApp: App {
    @StateObject private var sharedStore: NoteStore
    @StateObject private var primaryModel: AppModel
    @NSApplicationDelegateAdaptor(BanalAppDelegate.self) private var appDelegate

    static var uiTestWindowSize: CGSize? {
        let spec = ProcessInfo.processInfo.environment["BANAL_UI_TEST_WINDOW_SIZE"] ?? ""
        let parts = spec.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        let width = max(CGFloat(parts[0]), 720)
        let height = max(CGFloat(parts[1]), 520)
        return CGSize(width: width, height: height)
    }

    static func clearPersistedWindowFramesForUITest() {
        guard ProcessInfo.processInfo.environment["BANAL_UI_TEST_WINDOW_SIZE"] != nil else { return }
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("NSSplitView Subview Frames")
            || key.hasPrefix("NSWindow Frame")
            || key.hasPrefix("NSWindow Last Frame") {
            defaults.removeObject(forKey: key)
        }
    }

    static func uiTestFixtureVault() -> URL? {
        guard ProcessInfo.processInfo.environment["BANAL_UI_TEST_VAULT"] == "fixture" else { return nil }
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        if let stale = try? FileManager.default.contentsOfDirectory(at: caches, includingPropertiesForKeys: nil) {
            for url in stale where url.lastPathComponent.hasPrefix("banal-ui-test-") {
                try? FileManager.default.removeItem(at: url)
            }
        }
        let vault = caches.appendingPathComponent("banal-ui-test-\(UUID().uuidString)", isDirectory: true)
        let recipes = vault.appendingPathComponent("Recipes", isDirectory: true)
        try? FileManager.default.createDirectory(at: recipes, withIntermediateDirectories: true)
        try? Data(Self.fixtureGroceriesMarkdown.utf8).write(to: vault.appendingPathComponent("Groceries.md"))
        try? Data(Self.fixtureTextilePage.utf8).write(to: vault.appendingPathComponent("a-page.textile"))
        try? Data(Self.fixtureRisottoCook.utf8).write(to: recipes.appendingPathComponent("risotto.cook"))
        return vault
    }

    private static let fixtureGroceriesMarkdown = """
    ---
    title: Groceries
    created: 2026-08-21T09:00:00Z
    updated: 2026-08-21T09:00:00Z
    tags: [kitchen]
    ---

    # Groceries

    - Olive oil
    - Arborio rice
    - Parmesan

    ## Later

    Buy the good parmesan, not the pre-grated kind.
    """

    private static let fixtureTextilePage = """
    h1. A page

    A Textile page kept next to the recipes.

    * one
    * two
    """

    private static let fixtureRisottoCook = """
    >> title: Mushroom Risotto
    >> serves: 2

    Warm @stock{4%cups} in a pot.

    Melt @butter{2%tbsp} with @olive oil{1%tbsp} in @large pan{1}.

    Soften @shallot{1} and @mushrooms{250%g}.

    Add @arborio rice{1%cups} and toast.

    Ladle stock in slowly, stirring. About #18 minutes.

    Finish with @parmesan{30%g}.
    """

    init() {
        Self.clearPersistedWindowFramesForUITest()
        let remembered = Self.uiTestFixtureVault() ?? VaultBookmark.restore()
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
        let store = NoteStore(
            configuration: VaultConfiguration(rootURL: root),
            spotlightIndexer: NoteSpotlightIndexer.shared
        )
        let prefs = AppPreferencesStore.load()
        let model = AppModel(
            store: store,
            needsVault: needsVault,
            missingNotesFolder: missing,
            preferences: prefs
        )
        _sharedStore = StateObject(wrappedValue: store)
        _primaryModel = StateObject(wrappedValue: model)
    }

    var body: some Scene {
        WindowGroup(id: "main-window") {
            WindowRootView(
                sharedStore: sharedStore,
                fallbackModel: primaryModel,
                appDelegate: appDelegate
            )
        }
        .defaultSize(width: Self.uiTestWindowSize?.width ?? 1100, height: Self.uiTestWindowSize?.height ?? 720)
        .windowResizability(.contentMinSize)
        .commands {
            FileCommands(model: primaryModel)
            EditCommands(model: primaryModel)
            FindCommands(model: primaryModel)
            ViewCommands(model: primaryModel)

            CommandGroup(replacing: .appInfo) {
                Button("About BANAL") {
                    BanalAbout.show()
                }
            }

            CommandGroup(replacing: .help) {
                Button("BANAL Help") {
                    BanalHelp.show()
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

        Settings {
            SettingsRoot(model: primaryModel)
        }
    }
}

struct WindowRootView: View {
    @ObservedObject var sharedStore: NoteStore
    var fallbackModel: AppModel
    var appDelegate: BanalAppDelegate
    @StateObject private var model: AppModel

    init(sharedStore: NoteStore, fallbackModel: AppModel, appDelegate: BanalAppDelegate) {
        self.sharedStore = sharedStore
        self.fallbackModel = fallbackModel
        self.appDelegate = appDelegate
        _model = StateObject(wrappedValue: AppModel(
            store: sharedStore,
            needsVault: fallbackModel.needsVault,
            missingNotesFolder: fallbackModel.missingNotesFolder,
            preferences: fallbackModel.preferences
        ))
    }

    var body: some View {
        ContentView(model: model)
            .focusedObject(model)
            .onAppear {
                appDelegate.model = model
                WindowModelTracker.shared.activate(model)
                appDelegate.flushPendingOpens()
            }
            .onOpenURL { url in
                model.openExternalNote(at: url)
            }
            .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                if let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                    model.filter = .all
                    model.select(identifier)
                    model.focusEditor()
                }
            }
    }
}

enum BanalAbout {
    static let applicationName = "BANAL"
    static let version = "1.0"
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

enum BanalHelp {
    static let bookName: NSHelpManager.BookName = "dev.drawmeanelephant.banal.help"
    static let writeAnchor: NSHelpManager.AnchorName = "write"
    static let readPublishAnchor: NSHelpManager.AnchorName = "read-publish"

    @MainActor
    static func show() {
        let helpManager = NSHelpManager.shared
        _ = helpManager.registerBooks(in: .main)
        helpManager.openHelpAnchor(writeAnchor, inBook: bookName)
    }
}

@MainActor
final class BanalAppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    /// Open-file events (Finder double-click, Dock drag) that arrived
    /// before ContentView handed us the model. Drained in
    /// `flushPendingOpens()`.
    private var pendingOpenURLs: [URL] = []
    private var pendingServiceTexts: [String] = []

    /// A multi-file open (Finder multi-select → Open With, a Dock drag of
    /// several files) arrives as one Apple event. SwiftUI's `.onOpenURL`
    /// surfaces only the *first* URL; the rest reach this AppKit delegate
    /// hook, so without them a multi-select open was silently dropped.
    /// Implemented here (`open:` is the Swift name on every supported SDK
    /// — the ObjC selector `openURLs:` is renamed at import), routing the
    /// rest through the same queue as `.onOpenURL`. `AppModel` dedupes, so
    /// a single action can never import twice even when both routes fire.
    func application(_ application: NSApplication, open urls: [URL]) {
        pendingOpenURLs.append(contentsOf: urls)
        flushPendingOpens()
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        pendingOpenURLs.append(contentsOf: filenames.map { URL(fileURLWithPath: $0) })
        flushPendingOpens()
    }

    /// The model is set from `ContentView.onAppear`, which can race an
    /// open-file event during launch. Queue until then. Called only from
    /// MainActor contexts (the open-files delegate hook and `.onAppear`).
    @MainActor
    func flushPendingOpens() {
        if !pendingOpenURLs.isEmpty {
            let urls = pendingOpenURLs
            pendingOpenURLs.removeAll()
            for url in urls {
                model?.openExternalNote(at: url)
            }
        }
        if !pendingServiceTexts.isEmpty {
            let texts = pendingServiceTexts
            pendingServiceTexts.removeAll()
            for text in texts {
                model?.createNoteFromService(text: text)
            }
        }
    }

    @objc func newNoteFromService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = ServicesPasteboardParser.extractText(from: pboard) else {
            return
        }
        Task { @MainActor in
            if let model = self.model {
                model.createNoteFromService(text: text)
            } else {
                self.pendingServiceTexts.append(text)
            }
        }
    }

    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        if userActivity.activityType == CSSearchableItemActionType,
           let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
            Task { @MainActor in
                model?.filter = .all
                model?.select(identifier)
                model?.focusEditor()
            }
            return true
        }
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        if let size = BanalApp.uiTestWindowSize {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard let window = NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) }) else { return }
                var frame = window.frame
                frame.origin.x += (frame.width - size.width) / 2
                frame.origin.y += (frame.height - size.height) / 2
                frame.size = size
                window.setFrame(frame, display: true)
            }
        }
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
