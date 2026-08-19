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
                .onAppear { appDelegate.model = model }
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            model?.flushEditor()
            VaultBookmark.endAccess()
            SecurityScope.stopAll()
        }
    }
}
