import AppKit
import BANALCore
import BANALPublisher
import Combine
import Foundation
import SwiftUI

@MainActor
public final class AppModel: ObservableObject {
    @Published public var store: NoteStore
    @Published public var selectedID: String?
    @Published public var filter: SidebarFilter = .all
    @Published public var searchQuery: String = ""
    @Published public var editorText: String = ""
    @Published public var editorTitle: String = ""
    @Published public var editorTags: String = ""
    @Published public var editorPublished: Bool = false
    @Published public var searchFocusToken: Int = 0
    @Published public var findInNoteToken: Int = 0
    @Published public var statusMessage: String?
    @Published public var lastPublishResult: PublishResult?
    @Published public var needsVault: Bool
    @Published public var missingNotesFolder: Bool
    @Published public var preferences: AppPreferences
    @Published public var folderNameDraft: String = ""
    @Published public var isCreatingFolder = false
    @Published public var isRenamingFolder = false
    @Published public var folderBeingRenamed: String?
    /// Edit | Read for the open note — every language, not just recipes.
    @Published public var viewMode: ViewMode = .edit
    @Published public var recipeScale: RecipeScale = .one
    @Published public var oliverRecipe: OliverRecipe?
    @Published public var recipeError: String?
    /// One-sentence sauce problems from inlining (D-3): missing sauce,
    /// a cycle, too many levels. Non-fatal — the recipe still reads.
    @Published public var recipeIssues: [String] = []
    /// Identity for the open buffer. Changes when the user switches notes,
    /// not when a folder rename or move rewrites the path.
    @Published public private(set) var editorSessionID = UUID()
    /// Whether macOS 15+ Apple Intelligence Writing Tools is currently active.
    @Published public var isWritingToolsActive: Bool = false
    /// Currently selected text in the active editor buffer.
    @Published public var selectedText: String = ""
    /// Currently selected range in the active editor buffer.
    @Published public var selectedRange: NSRange = NSRange(location: 0, length: 0)
    /// Controls system translation sheet presentation (macOS 15+).
    @Published public var isTranslationPresented: Bool = false
    /// Text to present in the translation sheet.
    @Published public var translationText: String = ""

    public let sidebarFocus = FocusToken()
    public let noteListFocus = FocusToken()
    public let editorFocus = FocusToken()
    public let quickLook = FocusToken()
    /// Quiet word and character count for the currently edited note buffer (H-2).
    public var editorWordCountDescription: String {
        WordCount.count(in: editorText).formattedDescription
    }
    /// Last Oliver HTML for the open buffer. Published so the prose Read
    /// view (D-2) updates when the idle render lands; the editor itself
    /// ignores it (a render never changes the text).
    @Published public private(set) var lastOliverRender: OliverRender?
    private var suppressEditorSync = false
    private var editorDirty = false
    private var loadedFingerprint = ""
    private var loadedExtras: [FrontmatterExtra] = []
    private var warnedDiskFingerprint = ""
    /// Which selection and session the open buffer was loaded for. A write
    /// (F-9) must match both: an `onChange` echo from a previous load must
    /// never persist into a note it was not loaded for.
    private var loadedForID: String?
    private var loadedSessionID = UUID()
    private var cancellables = Set<AnyCancellable>()
    private var sessionViewMode: ViewMode = .edit
    private var recipeGeneration = 0
    private var oliverClient: OliverClient?
    private var oliver: OliverDebounce
    private let recipeQueue = DispatchQueue(label: "dev.drawmeanelephant.banal.recipe", qos: .userInitiated)
    /// Files opened (Finder double-click, Dock drag) before a vault exists.
    /// Imported once `bootstrap()` opens a notes folder.
    private var pendingImports: [URL] = []
    /// The last opened file, for dedupe. `.onOpenURL` and the delegate's
    /// `openFiles` can both fire for one user action; a single action must
    /// never import twice.
    private var lastHandledOpenURL: (url: URL, at: Date)?

    public init(
        store: NoteStore,
        needsVault: Bool = false,
        missingNotesFolder: Bool = false,
        preferences: AppPreferences = AppPreferencesStore.load()
    ) {
        self.store = store
        self.needsVault = needsVault
        self.missingNotesFolder = missingNotesFolder
        self.preferences = preferences
        store.watchesExternalEdits = preferences.watchExternalEdits
        if store.spotlightIndexer == nil {
            store.spotlightIndexer = NoteSpotlightIndexer.shared
        }
        self.oliverClient = nil
        self.oliver = OliverDebounce(client: nil)
        bindStore()
    }

    /// Honor the notes folder’s Oliver path without a relaunch.
    public func refreshOliver() {
        let configured = store.configuration.oliverBinaryPath
        _ = CompilerBookmark.access(path: configured, name: "oliver")
        recipeQueue.async { [weak self] in
            // Recipe Read needs `serialize --json`; a render-only Oliver is
            // not enough, so Read says “This recipe needs Oliver.” Idle
            // render keeps the plain fallback — older binaries still render.
            let recipeURL = OliverLocator.resolveRecipeJSON(configured: configured)
            let renderURL = recipeURL ?? OliverLocator.resolve(configured: configured)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.oliverClient = recipeURL.map { OliverClient(binaryURL: $0) }
                self.oliver = renderURL.map { OliverDebounce(client: OliverClient(binaryURL: $0)) }
                    ?? OliverDebounce(client: nil)
                if self.viewMode == .read, self.selectedNote?.language == .cooklang {
                    self.askRecipe()
                }
                if let client = self.oliverClient {
                    self.warmRecipeIngredientCache(with: client)
                }
            }
        }
    }

    private func bindStore() {
        cancellables.removeAll()
        store.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        store.$notes
            .sink { [weak self] _ in
                guard let self, !self.store.rootMissing else { return }
                self.reconcileFilter()
                self.reconcileExternalSelection()
            }
            .store(in: &cancellables)
        store.$rootMissing
            .sink { [weak self] missing in
                guard let self, missing else { return }
                self.needsVault = true
                self.missingNotesFolder = true
            }
            .store(in: &cancellables)
    }

    public var selectedNote: Note? {
        guard let selectedID else { return nil }
        return store.note(id: selectedID)
    }

    public var visibleNotes: [Note] {
        store.notes(matching: filter, query: searchQuery, sort: preferences.sort)
    }

    public var selectedFolderPath: String? {
        if case .folder(let path) = filter { return path }
        return nil
    }

    public func bootstrap() {
        do {
            try store.open()
            refreshOliver()
            if selectedID == nil {
                select(store.notes.first?.id)
            }
            drainPendingImports()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    /// A `.md`, `.textile`, or `.cook` file opened from Finder or dropped
    /// on the Dock icon. Inside the vault: select it. Outside: copy it in
    /// and select it. With no vault open yet, queue it until one opens.
    public func openExternalNote(at url: URL) {
        let standard = url.standardizedFileURL
        if let last = lastHandledOpenURL,
           last.url == standard,
           Date().timeIntervalSince(last.at) < 2 {
            return
        }
        lastHandledOpenURL = (standard, Date())
        guard !needsVault else {
            if !pendingImports.contains(url) {
                pendingImports.append(url)
            }
            return
        }
        openImportedNote(at: url)
    }

    private func openImportedNote(at url: URL) {
        let root = store.configuration.rootURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path == root || path.hasPrefix(root + "/") {
            let id = NoteIdentity.id(for: url, vaultURL: store.configuration.rootURL)
            if store.note(id: id) != nil {
                filter = .all
                select(id)
                editorFocus.request()
            } else {
                statusMessage = "Not a BANAL note file."
            }
            return
        }
        do {
            let imported = try store.importFile(from: url)
            filter = .all
            select(imported.id)
            editorFocus.request()
            statusMessage = "Imported “\(url.lastPathComponent)” into the notes folder."
            dismissStatusLater()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func drainPendingImports() {
        let urls = pendingImports
        pendingImports.removeAll()
        for url in urls {
            openImportedNote(at: url)
        }
    }

    public func presentImportPanel() {
        guard !needsVault else { return }
        guard let urls = ImportPicker.run(), !urls.isEmpty else { return }
        importItems(from: urls)
    }

    public func importItems(from urls: [URL]) {
        guard !needsVault else { return }
        flushEditor()
        let targetFolder = selectedFolderPath
        do {
            let result = try store.importItems(from: urls, targetFolder: targetFolder)
            if result.totalCount > 0 {
                if let firstNote = result.importedNotes.first {
                    if let targetFolder {
                        filter = .folder(targetFolder)
                    } else {
                        filter = .all
                    }
                    select(firstNote.id)
                    editorFocus.request()
                }
                statusMessage = result.summary
                dismissStatusLater()
            } else {
                statusMessage = "No supported notes or assets found to import."
                dismissStatusLater()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func select(_ id: String?) {
        if id == selectedID { return }
        persistEditor(to: selectedID)
        selectedID = id
        loadEditor(from: store.note(id: id ?? ""))
    }

    public var listSelection: Binding<String?> {
        Binding(
            get: { [weak self] in self?.selectedID },
            set: { [weak self] in self?.select($0) }
        )
    }

    /// Edit | Read applies to every note; recipes are not special.
    public var showsViewSwitcher: Bool {
        selectedNote != nil
    }

    /// Whether a render binary is configured — distinguishes the prose
    /// Read view's "Reading…" from "This note needs Oliver."
    public var oliverCanRender: Bool {
        oliver.isAvailable
    }

    public func createNote(language: NoteLanguage = .markdown, in folder: String? = nil) {
        do {
            let dest = folder ?? preferences.folderForNewNote(selected: filter)
            let note = try store.createNote(folder: dest, language: language)
            // New notes open in Edit, whatever the last note's mode.
            sessionViewMode = .edit
            if let dest {
                filter = .folder(dest)
            }
            select(note.id)
            editorFocus.request()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func beginNewFolder() {
        folderNameDraft = "Untitled Folder"
        isCreatingFolder = true
    }

    public func confirmNewFolder() {
        isCreatingFolder = false
        let name = folderNameDraft
        folderNameDraft = ""
        do {
            let created = try store.createFolder(name: name, parent: selectedFolderPath)
            filter = .folder(created.id)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func beginRenameFolder(_ id: String) {
        folderBeingRenamed = id
        folderNameDraft = (id as NSString).lastPathComponent
        isRenamingFolder = true
    }

    public func confirmRenameFolder() {
        isRenamingFolder = false
        let name = folderNameDraft
        let id = folderBeingRenamed
        folderBeingRenamed = nil
        folderNameDraft = ""
        guard let id else { return }
        do {
            let renamed = try store.renameFolder(id: id, to: name)
            if let selected = selectedID, let next = FolderPath.remap(selected, from: id, to: renamed.id) {
                selectedID = next
            }
            filter = .folder(renamed.id)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func trashSelectedFolder() {
        guard let path = selectedFolderPath else { return }
        do {
            try store.trashFolder(id: path)
            if let selected = selectedID, FolderPath.contains(selected, folder: path) {
                editorDirty = false
                selectedID = nil
            }
            filter = .all
            if selectedID == nil {
                select(store.notes.first?.id)
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func moveSelectedNote(to folder: String?) {
        guard let id = selectedID else { return }
        do {
            let moved = try store.moveNote(id: id, toFolder: folder)
            if let folder {
                filter = .folder(folder)
            }
            select(moved.id)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func dropNote(_ noteID: String, onto folder: String?) {
        let resolvedID: String
        if let direct = store.note(id: noteID) {
            resolvedID = direct.id
        } else if let match = store.notes.first(where: {
            $0.fileURL.path == noteID ||
            $0.fileURL.standardizedFileURL.path == URL(fileURLWithPath: noteID).standardizedFileURL.path ||
            $0.fileURL.absoluteString == noteID ||
            $0.id == noteID
        }) {
            resolvedID = match.id
        } else {
            resolvedID = noteID
        }
        do {
            let moved = try store.moveNote(id: resolvedID, toFolder: folder)
            if selectedID == resolvedID {
                selectedID = moved.id
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func dropNote(with url: URL, onto folder: String?) {
        if let match = store.notes.first(where: {
            $0.fileURL.standardizedFileURL == url.standardizedFileURL ||
            $0.fileURL.path == url.path
        }) {
            dropNote(match.id, onto: folder)
        } else {
            let vaultPath = store.configuration.rootURL.standardizedFileURL.path
            let itemPath = url.standardizedFileURL.path
            if itemPath.hasPrefix(vaultPath) {
                let relative = String(itemPath.dropFirst(vaultPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                dropNote(relative, onto: folder)
            } else {
                dropNote(url.path, onto: folder)
            }
        }
    }

    public func savePreferences() {
        AppPreferencesStore.save(preferences)
        store.watchesExternalEdits = preferences.watchExternalEdits
    }

    public func saveVaultConfiguration() {
        updateVaultConfiguration(store.configuration)
    }

    public func updateVaultConfiguration(_ next: VaultConfiguration) {
        let oliverChanged = next.oliverBinaryPath != store.configuration.oliverBinaryPath
        do {
            try store.updateConfiguration(next)
            if oliverChanged {
                refreshOliver()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func trashSelected() {
        guard let id = selectedID else { return }
        let remaining = visibleNotes.filter { $0.id != id }
        do {
            try store.trash(id: id)
            select(remaining.first?.id)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func applyEditorChanges() {
        guard !suppressEditorSync,
              selectedID == loadedForID,
              editorSessionID == loadedSessionID,
              var note = selectedNote else { return }
        let tags = editorTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if note.title == editorTitle, note.body == editorText, note.tags == tags, note.published == editorPublished {
            return
        }
        editorDirty = true
        let bodyChanged = note.body != editorText
        note.title = editorTitle
        note.body = editorText
        note.tags = tags
        note.published = editorPublished
        store.update(note, debounce: true)
        if bodyChanged {
            scheduleOliverQuestion()
        }
    }

    public func flushEditor() {
        guard !store.rootMissing else { return }
        persistEditor(to: selectedID)
        store.flush()
    }

    private func persistEditor(to id: String?) {
        guard !isWritingToolsActive else { return }
        guard editorDirty,
              selectedID == loadedForID,
              editorSessionID == loadedSessionID,
              let id,
              var note = store.note(id: id) else { return }
        note.title = editorTitle
        note.body = editorText
        note.tags = editorTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        note.published = editorPublished
        store.update(note, debounce: false)
        if let saved = store.note(id: id) {
            loadedFingerprint = saved.contentFingerprint
            loadedExtras = saved.extras
            editorDirty = false
        }
    }

    private func reconcileExternalSelection() {
        guard !suppressEditorSync, let id = selectedID else { return }
        let disk = store.note(id: id)
        let tagList = editorTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let bufferMatches = disk.map {
            $0.title == editorTitle
                && $0.body == editorText
                && $0.tags == tagList
                && $0.published == editorPublished
                && $0.extras == loadedExtras
        } ?? false
        switch ExternalEdit.action(
            selectedStillOnDisk: disk != nil,
            dirty: editorDirty,
            loadedFingerprint: loadedFingerprint,
            diskFingerprint: disk?.contentFingerprint ?? "",
            bufferMatchesDisk: bufferMatches,
            isWritingToolsActive: isWritingToolsActive
        ) {
        case .ignore:
            if bufferMatches {
                editorDirty = false
            }
            if let disk {
                loadedFingerprint = disk.contentFingerprint
                loadedExtras = disk.extras
            }
        case .reload:
            loadEditor(from: disk)
        case .keepBuffer:
            let mark = disk?.contentFingerprint ?? ""
            if warnedDiskFingerprint != mark {
                warnedDiskFingerprint = mark
                statusMessage = "This file changed on disk. Your edits were kept."
            }
        case .noteGone(let keep):
            if keep {
                statusMessage = "This file was moved or deleted. Your edits were kept."
            } else {
                select(store.notes.first?.id)
            }
        }
    }

    public func revealSelected() {
        if let note = selectedNote {
            NSWorkspace.shared.activateFileViewerSelecting([note.fileURL])
            return
        }
        if let folder = selectedFolderPath {
            let url = store.configuration.rootURL.appendingPathComponent(folder, isDirectory: true)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }
        revealVault()
    }

    public func focusSidebar() {
        sidebarFocus.request()
    }

    public func focusNoteList() {
        if selectedID == nil, let first = visibleNotes.first {
            select(first.id)
        }
        noteListFocus.request()
    }

    public func focusEditor() {
        guard selectedID != nil else { return }
        if viewMode != .edit {
            setViewMode(.edit)
        }
        editorFocus.request()
    }

    public func toggleQuickLook() {
        guard selectedID != nil else { return }
        quickLook.request()
    }

    public func focusSearch() {
        searchFocusToken += 1
    }

    public func findInNote() {
        findInNoteToken += 1
    }

    public func togglePublished() {
        editorPublished.toggle()
        applyEditorChanges()
    }

    public func printSelectedNote(window: NSWindow? = nil) {
        flushEditor()
        guard let note = selectedNote else { return }
        let isRecipeRead = (viewMode == .read && note.language == .cooklang)
        NotePrintCoordinator.printNote(
            note,
            isRecipeReadMode: isRecipeRead,
            oliverRecipe: oliverRecipe,
            scale: recipeScale,
            window: window
        )
    }

    public func shareSelectedNote(from view: NSView? = nil, window: NSWindow? = nil) {
        flushEditor()
        guard let note = selectedNote else { return }
        NoteShareCoordinator.shareNote(note, from: view, window: window)
    }

    public func createNoteFromService(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let dest = (preferences.newNoteLocation == .vaultRoot) ? nil : (preferences.folderForNewNote(selected: filter) ?? "Inbox")
        let resolvedTitle = inferredTitle(from: trimmed) ?? "Note"
        do {
            let note = try store.createNote(
                title: resolvedTitle,
                body: trimmed,
                folder: dest,
                language: .markdown
            )
            sessionViewMode = .edit
            if let dest {
                filter = .folder(dest)
            } else {
                filter = .all
            }
            select(note.id)
            editorFocus.request()
            NSApp.activate(ignoringOtherApps: true)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public var canCopyAs: Bool {
        selectedNote != nil
    }

    public var copyAsSourceText: String {
        if !selectedText.isEmpty {
            return selectedText
        }
        if viewMode == .edit {
            return editorText
        }
        return selectedNote?.body ?? ""
    }

    public func copyAs(_ format: CopyAsFormat) {
        guard let note = selectedNote else { return }
        let source = copyAsSourceText
        guard !source.isEmpty else { return }
        let language = note.language
        CopyAsConverter.copy(
            source,
            format: format,
            language: language,
            title: note.displayTitle,
            directory: note.fileURL.deletingLastPathComponent()
        )
    }

    public var canTranslate: Bool {
        guard selectedNote != nil, viewMode == .edit else { return false }
        return TranslationState.isValidTranslationText(selectedText)
    }

    public func translateSelection() {
        guard canTranslate else { return }
        translationText = selectedText
        if #available(macOS 15.0, *) {
            isTranslationPresented = true
        } else {
            triggerNativeTranslation()
        }
    }

    public func replaceSelectedText(with replacement: String) {
        guard let (newBody, newRange) = TranslationState.replaceSelectedText(
            in: editorText,
            range: selectedRange,
            with: replacement
        ) else { return }
        editorText = newBody
        selectedRange = newRange
        selectedText = ""
        applyEditorChanges()
    }

    public var insertAtCaretHandler: ((String) -> Bool)?

    public func insertTextAtCaret(_ text: String) {
        if let handler = insertAtCaretHandler, handler(text) {
            return
        }
        let range = selectedRange
        let nsText = editorText as NSString
        let safeLocation = min(range.location, nsText.length)
        let safeLength = min(range.length, nsText.length - safeLocation)
        let safeRange = NSRange(location: safeLocation, length: safeLength)
        let newText = nsText.replacingCharacters(in: safeRange, with: text)
        editorText = newText
        selectedRange = NSRange(location: safeLocation + (text as NSString).length, length: 0)
        selectedText = ""
        applyEditorChanges()
    }

    public func insertContact(window: NSWindow? = nil, view: NSView? = nil) {
        guard selectedNote != nil, viewMode == .edit, !needsVault else { return }
        let targetWindow = window ?? NSApp.keyWindow ?? NSApp.mainWindow
        let targetView = view ?? targetWindow?.firstResponder as? NSView ?? targetWindow?.contentView
        guard let targetView else { return }

        let rect: NSRect
        if let textView = targetView as? NSTextView, let window = textView.window {
            let sel = textView.selectedRange()
            let screenRect = textView.firstRect(forCharacterRange: sel, actualRange: nil)
            if screenRect.width > 0 && screenRect.height > 0 {
                let windowRect = window.convertFromScreen(screenRect)
                rect = textView.convert(windowRect, from: nil)
            } else {
                rect = textView.visibleRect
            }
        } else {
            rect = targetView.bounds
        }

        ContactPickerPresenter.shared.present(relativeTo: rect, of: targetView) { [weak self] formatted in
            Task { @MainActor [weak self] in
                self?.insertTextAtCaret(formatted)
            }
        }
    }

    public func insertFile(window: NSWindow? = nil) {
        guard selectedNote != nil, viewMode == .edit, !needsVault else { return }
        let targetWindow = window ?? NSApp.keyWindow ?? NSApp.mainWindow
        let title = selectedText.isEmpty ? nil : selectedText
        FilePickerPresenter.present(
            in: targetWindow,
            vaultURL: store.configuration.rootURL,
            linkTitle: title
        ) { [weak self] link in
            Task { @MainActor [weak self] in
                self?.insertTextAtCaret(link)
            }
        }
    }

    public func triggerNativeTranslation() {
        NSApp.sendAction(NSSelectorFromString("translate:"), to: nil, from: nil)
    }

    public var canInsertPhoto: Bool {
        !needsVault && selectedNote != nil && viewMode == .edit
    }

    public func insertPhoto() {
        guard canInsertPhoto else { return }
        let panel = NSOpenPanel()
        panel.title = "Insert Photo"
        panel.prompt = "Insert"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = AssetManager.supportedContentTypes

        let response = panel.runModal()
        guard response == .OK, !panel.urls.isEmpty else { return }

        let vaultURL = store.configuration.rootURL
        var links: [String] = []
        for url in panel.urls {
            do {
                let result = try AssetManager.importAsset(from: url, vaultURL: vaultURL)
                links.append(result.markdownLink)
            } catch {
                statusMessage = error.localizedDescription
            }
        }
        guard !links.isEmpty else { return }
        let insertion = links.joined(separator: "\n\n")
        insertTextIntoEditor(insertion)
        editorFocus.request()
    }

    public func insertTextIntoEditor(_ insertion: String) {
        let nsText = editorText as NSString
        let range: NSRange
        if selectedRange.location != NSNotFound, selectedRange.location + selectedRange.length <= nsText.length {
            range = selectedRange
        } else {
            range = NSRange(location: nsText.length, length: 0)
        }
        let newText = nsText.replacingCharacters(in: range, with: insertion)
        editorText = newText
        let newCaret = range.location + (insertion as NSString).length
        selectedRange = NSRange(location: newCaret, length: 0)
        selectedText = ""
        applyEditorChanges()
    }
    public func dismissStatusLater() {
        let message = statusMessage
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }

    public func openVault(_ url: URL) {
        flushEditor()
        store.flush()
        store.monitorStopForReplacement()
        VaultBookmark.endAccess()
        let next = NoteStore(
            configuration: VaultConfiguration(rootURL: url),
            spotlightIndexer: NoteSpotlightIndexer.shared
        )
        next.watchesExternalEdits = preferences.watchExternalEdits
        store = next
        bindStore()
        needsVault = false
        missingNotesFolder = false
        VaultBookmark.save(url)
        bootstrap()
    }

    public var canDeploy: Bool {
        CloudflareDeployer.canDeploy(
            projectName: store.configuration.cloudflareProjectName,
            token: PublishKeychain.token(vaultURL: store.configuration.rootURL)
        )
    }

    public func publishSite() {
        flushEditor()
        do {
            let result = try publishNow()
            lastPublishResult = result
            statusMessage = result.statusCopy
            NSWorkspace.shared.activateFileViewerSelecting([result.artifactDirectory])
        } catch PublishError.noPublishedNotes {
            statusMessage = "Nothing published."
        } catch PublishError.nothingCompiled {
            statusMessage = "Nothing published — recipes need Oliver."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func deployToCloudflare() {
        flushEditor()
        let vault = store.configuration
        guard let token = PublishKeychain.token(vaultURL: vault.rootURL),
              CloudflareDeployer.canDeploy(projectName: vault.cloudflareProjectName, token: token)
        else {
            statusMessage = "Not connected — publishing stays on this Mac."
            return
        }
        do {
            let index = vault.publishURL.appendingPathComponent("index.html")
            if !FileManager.default.fileExists(atPath: index.path) {
                _ = try publishNow()
            }
            let plan = CloudflareDeployer.plan(
                artifactDirectory: vault.publishURL,
                projectName: vault.cloudflareProjectName,
                accountID: vault.cloudflareAccountID,
                dryRun: false
            )
            _ = try CloudflareDeployer.deploy(plan: plan, token: token)
            statusMessage = "Deployed to Cloudflare Pages."
        } catch CloudflareDeployError.wranglerMissing {
            statusMessage = "Can’t deploy — wrangler isn’t installed."
        } catch CloudflareDeployError.failed(_, let log) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(log, forType: .string)
            statusMessage = "Deploy failed. The log is on the clipboard."
        } catch PublishError.noPublishedNotes {
            statusMessage = "Nothing published."
        } catch PublishError.nothingCompiled {
            statusMessage = "Nothing published — recipes need Oliver."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func publishNow() throws -> PublishResult {
        let vault = store.configuration
        _ = CompilerBookmark.access(path: vault.borisBinaryPath, name: "boris")
        _ = CompilerBookmark.access(path: vault.oliverBinaryPath, name: "oliver")
        let configuration = PublishConfiguration.default(for: vault)
        return try BANALPublisher.make(configuration: configuration).publish(
            notes: store.notes,
            vault: vault,
            configuration: configuration
        )
    }

    public func revealVault() {
        // J-13d: prefer live bookmark resolution after Finder rename-while-quit.
        // `store.configuration.rootURL` is the snapshot from launch; a rename
        // while quit re-resolves via bookmark data to the new inode path.
        // `VaultBookmark.restore()` re-resolves (or honors BANAL_VAULT) and
        // falls back to the stored URL only for firstRun (nil).
        let live = VaultBookmark.restore() ?? store.configuration.rootURL
        NSWorkspace.shared.activateFileViewerSelecting([live])
    }

    private func reconcileFilter() {
        if case .folder(let path) = filter, !store.folders.contains(path) {
            filter = .all
        }
    }

    public func setViewMode(_ mode: ViewMode) {
        guard selectedNote != nil else { return }
        if viewMode == mode { return }
        viewMode = mode
        sessionViewMode = mode
        if mode == .read {
            flushEditor()
            if selectedNote?.language == .cooklang {
                oliverRecipe = nil
                recipeError = nil
                askRecipe()
            } else {
                scheduleOliverQuestion()
            }
        } else {
            cancelRecipeAsk()
            clearRecipe()
        }
        if mode != .edit {
            selectedText = ""
            isTranslationPresented = false
        }
    }

    public func setRecipeScale(_ scale: RecipeScale) {
        guard recipeScale != scale else { return }
        recipeScale = scale
        if viewMode == .read, selectedNote?.language == .cooklang {
            askRecipe()
        }
    }

    private func loadEditor(from note: Note?) {
        // The buffer belongs to this selection and this session from here
        // on; only writes matching both are allowed (F-9).
        editorSessionID = UUID()
        loadedForID = selectedID
        loadedSessionID = editorSessionID
        suppressEditorSync = true
        editorTitle = note?.title ?? ""
        editorText = note?.body ?? ""
        editorTags = note?.tags.joined(separator: ", ") ?? ""
        editorPublished = note?.published ?? false
        loadedFingerprint = note?.contentFingerprint ?? ""
        loadedExtras = note?.extras ?? []
        editorDirty = false
        warnedDiskFingerprint = ""
        recipeScale = .one
        selectedText = ""
        selectedRange = NSRange(location: 0, length: 0)
        isTranslationPresented = false
        translationText = ""
        suppressEditorSync = false
        viewMode = sessionViewMode
        if viewMode == .read, note?.language == .cooklang {
            askRecipe()
        } else {
            cancelRecipeAsk()
            clearRecipe()
        }
        scheduleOliverQuestion()
    }

    /// Ask Oliver what this buffer is, after idle. Missing binary is
    /// silent. The process runs off the main queue so typing never waits.
    private func scheduleOliverQuestion() {
        guard oliver.isAvailable else {
            lastOliverRender = nil
            return
        }
        let noteID = selectedID
        let frontend = OliverFrontend(language: selectedNote?.language ?? .markdown)
        oliver.schedule(source: editorText, frontend: frontend) { [weak self] render in
            Task { @MainActor [weak self] in
                guard let self, self.selectedID == noteID else { return }
                self.lastOliverRender = render
            }
        }
        if selectedNote?.language == .cooklang, let client = oliverClient, let note = selectedNote {
            let source = editorText
            let directory = note.fileURL.deletingLastPathComponent()
            let targetID = note.id
            recipeQueue.async { [weak self] in
                let inlined = RecipeInliner.inline(
                    source: source,
                    relativeTo: directory,
                    scaler: { try client.scaleSource($0, percent: $1) }
                )
                if let recipe = try? client.recipe(inlined.source, scale: .one) {
                    let names = recipe.ingredientIndex.map(\.name)
                    Task { @MainActor [weak self] in
                        guard let self, let current = self.store.note(id: targetID) else { return }
                        self.store.setCachedIngredients(names, for: targetID, fingerprint: current.contentFingerprint)
                    }
                }
            }
        }
    }

    private func warmRecipeIngredientCache(with client: OliverClient) {
        let cookNotes = store.notes.filter { $0.language == .cooklang }
        recipeQueue.async { [weak self] in
            for note in cookNotes {
                let directory = note.fileURL.deletingLastPathComponent()
                let inlined = RecipeInliner.inline(
                    source: note.body,
                    relativeTo: directory,
                    scaler: { try client.scaleSource($0, percent: $1) }
                )
                if let recipe = try? client.recipe(inlined.source, scale: .one) {
                    let names = recipe.ingredientIndex.map(\.name)
                    Task { @MainActor [weak self] in
                        self?.store.setCachedIngredients(names, for: note.id, fingerprint: note.contentFingerprint)
                    }
                }
            }
        }
    }

    private func askRecipe() {
        guard viewMode == .read, selectedNote?.language == .cooklang else {
            clearRecipe()
            return
        }
        guard let client = oliverClient else {
            oliverRecipe = nil
            recipeError = "This recipe needs Oliver."
            recipeIssues = []
            return
        }
        recipeGeneration += 1
        let generation = recipeGeneration
        let source = editorText
        let directory = selectedNote?.fileURL.deletingLastPathComponent()
        let scale = recipeScale
        let noteID = selectedID
        let apply: @Sendable (Result<OliverRecipe, Error>, [String]) -> Void = { [weak self] result, issues in
            Task { @MainActor in
                guard let self else { return }
                guard generation == self.recipeGeneration, self.viewMode == .read, self.selectedID == noteID else { return }
                switch result {
                case .success(let recipe):
                    self.oliverRecipe = recipe
                    self.recipeError = nil
                    self.recipeIssues = issues
                    if let noteID, let note = self.store.note(id: noteID) {
                        self.store.setCachedIngredients(recipe.ingredientIndex.map(\.name), for: noteID, fingerprint: note.contentFingerprint)
                    }
                case .failure:
                    self.oliverRecipe = nil
                    self.recipeError = "This recipe didn’t parse."
                    self.recipeIssues = issues
                }
            }
        }
        recipeQueue.async { [client, directory] in
            do {
                // D-3: walk `@./path{scale}` refs before Oliver sees the
                // source — a path walk, never a rewrite of the file.
                let inlined = directory.map {
                    RecipeInliner.inline(
                        source: source,
                        relativeTo: $0,
                        scaler: { try client.scaleSource($0, percent: $1) }
                    )
                }
                let recipe = try client.recipe(inlined?.source ?? source, scale: scale)
                apply(.success(recipe), inlined?.issues ?? [])
            } catch {
                apply(.failure(error), [])
            }
        }
    }

    private func cancelRecipeAsk() {
        recipeGeneration += 1
    }

    private func clearRecipe() {
        oliverRecipe = nil
        recipeError = nil
        recipeIssues = []
    }
}

public enum ViewMode: String, Equatable, Hashable, Sendable {
    case edit
    case read
}

public final class FocusToken {
    public var handler: (() -> Void)?
    public func request() { handler?() }
}

extension NoteStore {
    fileprivate func monitorStopForReplacement() {
        flush()
    }
}
