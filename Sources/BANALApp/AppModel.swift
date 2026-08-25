import AppKit
import BANALAppModel
import BANALCore
import BANALPublisher
import Combine
import Foundation
import SwiftUI

/// Coordinator: owns the store and the focused sub-controllers, wires
/// them together, and keeps selection + filter + status. The domains
/// themselves live in `BANALAppModel` — editor session (#181), recipes,
/// folders, imports, publishing, enrichment, translation.
@MainActor
public final class AppModel: ObservableObject {
    @Published public var store: NoteStore
    @Published public var selectedID: String?
    @Published public var filter: SidebarFilter = .all
    @Published public var searchQuery: String = ""
    @Published public var searchFocusToken: Int = 0
    @Published public var findInNoteToken: Int = 0
    @Published public var statusMessage: String?
    @Published public var needsVault: Bool
    @Published public var missingNotesFolder: Bool
    @Published public var preferences: AppPreferences
    /// Edit | Read for the open note — every language, not just recipes.
    @Published public var viewMode: ViewMode = .edit
    /// Whether macOS 15+ Apple Intelligence Writing Tools is currently active.
    @Published public var isWritingToolsActive: Bool = false

    // Focused sub-controllers (#181).
    public let editor = EditorSession()
    public let recipe = RecipeSession()
    public let folder = FolderController()
    public let translation = TranslationController()
    public let enrichment = EnrichmentController()
    public let imports = ImportController()
    public let publisher = PublishController()

    public let sidebarFocus = FocusToken()
    public let noteListFocus = FocusToken()
    public let editorFocus = FocusToken()
    public let quickLook = FocusToken()

    private var cancellables = Set<AnyCancellable>()
    private var sessionViewMode: ViewMode = .edit

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
        recipe.context = self
        bindStore()
    }

    /// Honor the notes folder's Oliver path without a relaunch.
    public func refreshOliver() {
        recipe.refreshOliver(configured: store.configuration.oliverBinaryPath)
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
        bindControllers()
    }

    /// Child state changes must re-render views that read it through
    /// coordinator passthroughs.
    private func bindControllers() {
        for change in [
            editor.objectWillChange,
            recipe.objectWillChange,
            folder.objectWillChange,
            translation.objectWillChange,
        ] {
            change
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    // MARK: - Selection and listing

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

    public func select(_ id: String?) {
        if id == selectedID { return }
        persistSelection()
        selectedID = id
        loadEditor(from: store.note(id: id ?? ""))
    }

    public var listSelection: Binding<String?> {
        Binding(
            get: { [weak self] in self?.selectedID },
            set: { [weak self] in self?.select($0) }
        )
    }

    // MARK: - Editor passthroughs

    public var editorText: String {
        get { editor.editorText }
        set { editor.editorText = newValue }
    }

    public var editorTitle: String {
        get { editor.editorTitle }
        set { editor.editorTitle = newValue }
    }

    public var editorTags: String {
        get { editor.editorTags }
        set { editor.editorTags = newValue }
    }

    public var editorPublished: Bool {
        get { editor.editorPublished }
        set { editor.editorPublished = newValue }
    }

    public var editorSessionID: UUID {
        editor.editorSessionID
    }

    /// Quiet word and character count for the currently edited note buffer (H-2).
    public var editorWordCountDescription: String {
        editor.wordCountDescription
    }

    public var selectedText: String {
        get { editor.selectedText }
        set { editor.selectedText = newValue }
    }

    public var selectedRange: NSRange {
        get { editor.selectedRange }
        set { editor.selectedRange = newValue }
    }

    public var insertAtCaretHandler: ((String) -> Bool)? {
        get { editor.insertAtCaretHandler }
        set { editor.insertAtCaretHandler = newValue }
    }

    // Bindings: views keep using `$model.<field>` projections — the
    // passthroughs above are writable key paths, so SwiftUI binds them
    // directly. No explicit Binding helpers needed.

    public var isTranslationPresented: Bool {
        get { translation.isPresented }
        set { translation.isPresented = newValue }
    }

    public var translationText: String {
        get { translation.text }
        set { translation.text = newValue }
    }

    // MARK: - Editor flows

    public func applyEditorChanges() {
        guard let note = selectedNote else { return }
        guard let change = editor.applyChanges(to: note, selectedID: selectedID) else { return }
        store.update(change.updated, debounce: true)
        if change.bodyChanged {
            recipe.scheduleIdleRender()
        }
    }

    public func flushEditor() {
        guard !store.rootMissing else { return }
        persistSelection()
        store.flush()
    }

    private func persistSelection() {
        guard let id = selectedID else { return }
        if let renamed = editor.persist(to: id, store: store, writingToolsActive: isWritingToolsActive),
           selectedID == id {
            selectedID = renamed
        }
    }

    private func reconcileExternalSelection() {
        guard !editor.isSuppressed, let id = selectedID else { return }
        let disk = store.note(id: id)
        switch ExternalEdit.action(
            selectedStillOnDisk: disk != nil,
            dirty: editor.isDirty,
            loadedFingerprint: editor.loadedFingerprint,
            diskFingerprint: disk?.contentFingerprint ?? "",
            bufferMatchesDisk: editor.bufferMatchesDisk(disk),
            isWritingToolsActive: isWritingToolsActive
        ) {
        case .ignore:
            editor.acceptIgnoredExternalState(disk)
        case .reload:
            loadEditor(from: disk)
        case .keepBuffer:
            if editor.markDiskChangeWarning(fingerprint: disk?.contentFingerprint ?? "") {
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

    private func loadEditor(from note: Note?) {
        editor.load(from: note, selectedID: selectedID)
        recipe.recipeScale = .one
        translation.reset()
        viewMode = sessionViewMode
        if viewMode == .read, note?.language == .cooklang {
            recipe.askOliverForRecipe()
        } else {
            recipe.cancelRecipeAsk()
            recipe.clearRecipe()
        }
        recipe.scheduleIdleRender()
    }

    // MARK: - Notes

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

    // MARK: - Folders

    public var folderNameDraft: String {
        get { folder.nameDraft }
        set { folder.nameDraft = newValue }
    }

    public var isCreatingFolder: Bool {
        get { folder.isCreating }
        set { folder.isCreating = newValue }
    }

    public var isRenamingFolder: Bool {
        get { folder.isRenaming }
        set { folder.isRenaming = newValue }
    }

    public func beginNewFolder() {
        folder.beginNewFolder()
    }

    public func confirmNewFolder() {
        do {
            let created = try folder.confirmNewFolder(store: store, parent: selectedFolderPath)
            filter = .folder(created.id)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func beginRenameFolder(_ id: String) {
        folder.beginRename(id)
    }

    public func confirmRenameFolder() {
        do {
            guard let result = try folder.confirmRename(store: store) else { return }
            if let selected = selectedID, let next = FolderPath.remap(selected, from: result.previousID, to: result.renamed.id) {
                selectedID = next
            }
            filter = .folder(result.renamed.id)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func trashSelectedFolder() {
        guard let path = selectedFolderPath else { return }
        do {
            try store.trashFolder(id: path)
            if let selected = selectedID, FolderPath.contains(selected, folder: path) {
                editor.discardPendingWrite()
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
        let resolvedID = FolderController.resolvedMoveTarget(for: noteID, notes: store.notes)
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
        dropNote(
            FolderController.resolvedMoveTarget(for: url, vaultRoot: store.configuration.rootURL, notes: store.notes),
            onto: folder
        )
    }

    // MARK: - Import / Services

    /// A `.md`, `.textile`, or `.cook` file opened from Finder or dropped
    /// on the Dock icon. Inside the vault: select it. Outside: copy it in
    /// and select it. With no vault open yet, queue it until one opens.
    public func openExternalNote(at url: URL) {
        let decision = imports.openExternalNote(
            at: url,
            vaultRoot: store.configuration.rootURL,
            needsVault: needsVault,
            importer: { try store.importFile(from: $0) },
            noteExists: { store.note(id: $0) != nil }
        )
        handle(decision, openedFile: url.lastPathComponent)
    }

    private func drainPendingImports() {
        let drained = imports.drainPendingImports(
            vaultRoot: store.configuration.rootURL,
            importer: { try store.importFile(from: $0) },
            noteExists: { store.note(id: $0) != nil }
        )
        for (url, decision) in drained {
            handle(decision, openedFile: url.lastPathComponent)
        }
    }

    private func handle(_ decision: ImportController.OpenDecision, openedFile: String?) {
        switch decision {
        case .selectExisting(let id):
            filter = .all
            select(id)
            editorFocus.request()
        case .notANote:
            statusMessage = "Not a BANAL note file."
        case .imported(let id):
            filter = .all
            select(id)
            editorFocus.request()
            if let openedFile {
                statusMessage = "Imported “\(openedFile)” into the notes folder."
                dismissStatusLater()
            }
        case .queued:
            break
        case .failed(let message):
            statusMessage = message
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

    public func createNoteFromService(text: String) {
        let dest = (preferences.newNoteLocation == .vaultRoot) ? nil : (preferences.folderForNewNote(selected: filter) ?? "Inbox")
        switch imports.createServiceNote(text: text, store: store, destinationFolder: dest) {
        case .created(let note, let destinationFolder):
            sessionViewMode = .edit
            if let destinationFolder {
                filter = .folder(destinationFolder)
            } else {
                filter = .all
            }
            select(note.id)
            editorFocus.request()
            NSApp.activate(ignoringOtherApps: true)
        case .emptyText:
            break
        case .failed(let message):
            statusMessage = message
        }
    }

    // MARK: - View mode and recipes

    /// Edit | Read applies to every note; recipes are not special.
    public var showsViewSwitcher: Bool {
        selectedNote != nil
    }

    /// Whether a render binary is configured — distinguishes the prose
    /// Read view's "Reading…" from "This note needs Oliver."
    public var oliverCanRender: Bool {
        recipe.canRender
    }

    public var recipeScale: RecipeScale {
        recipe.recipeScale
    }

    public var oliverRecipe: OliverRecipe? {
        recipe.oliverRecipe
    }

    public var recipeError: String? {
        recipe.recipeError
    }

    public var recipeIssues: [String] {
        recipe.recipeIssues
    }

    /// Last Oliver HTML for the open buffer. Published so the prose Read
    /// view (D-2) updates when the idle render lands; the editor itself
    /// ignores it (a render never changes the text).
    public var lastOliverRender: OliverRender? {
        recipe.lastOliverRender
    }

    public func setViewMode(_ mode: ViewMode) {
        guard selectedNote != nil else { return }
        if viewMode == mode { return }
        viewMode = mode
        sessionViewMode = mode
        if mode == .read {
            flushEditor()
            if selectedNote?.language == .cooklang {
                recipe.oliverRecipe = nil
                recipe.recipeError = nil
                recipe.askOliverForRecipe()
            } else {
                recipe.scheduleIdleRender()
            }
        } else {
            recipe.cancelRecipeAsk()
            recipe.clearRecipe()
        }
        if mode != .edit {
            editor.selectedText = ""
            translation.isPresented = false
        }
    }

    public func setRecipeScale(_ scale: RecipeScale) {
        guard recipe.recipeScale != scale else { return }
        recipe.recipeScale = scale
        if viewMode == .read, selectedNote?.language == .cooklang {
            recipe.askOliverForRecipe()
        }
    }

    public func togglePublished() {
        editor.editorPublished.toggle()
        applyEditorChanges()
    }

    // MARK: - Save Scaled Copy / Convert Textile

    /// Write a scaled copy of the current recipe to disk. The original
    /// is never mutated; the copy is selected once the monitor sees it.
    public func saveScaledCopy() {
        guard let note = selectedNote else { return }
        if let newURL = recipe.saveScaledCopy(of: note) {
            selectOnceVisible(newURL)
        }
    }

    /// Convert the selected `.textile` note to `.md` via Oliver +
    /// HTMLToMarkdown. The original is moved to Trash. Only on explicit
    /// user request.
    public func convertTextileToMarkdown() {
        guard let note = selectedNote else { return }
        if let newURL = recipe.convertTextileToMarkdown(of: note) {
            selectOnceVisible(newURL)
        }
    }

    /// Let the file monitor pick a freshly written file up, then select it.
    private func selectOnceVisible(_ url: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            if let newNote = self.store.notes.first(where: { $0.fileURL == url }) {
                self.select(newNote.id)
            }
        }
    }

    // MARK: - Print, share, copy

    public func printSelectedNote(window: NSWindow? = nil) {
        flushEditor()
        guard let note = selectedNote else { return }
        let isRecipeRead = (viewMode == .read && note.language == .cooklang)
        NotePrintCoordinator.printNote(
            note,
            isRecipeReadMode: isRecipeRead,
            oliverRecipe: recipe.oliverRecipe,
            scale: recipe.recipeScale,
            window: window
        )
    }

    public func shareSelectedNote(from view: NSView? = nil, window: NSWindow? = nil) {
        flushEditor()
        guard let note = selectedNote else { return }
        NoteShareCoordinator.shareNote(note, from: view, window: window)
    }

    public var canCopyAs: Bool {
        selectedNote != nil
    }

    public var copyAsSourceText: String {
        if !editor.selectedText.isEmpty {
            return editor.selectedText
        }
        if viewMode == .edit {
            return editor.editorText
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

    // MARK: - Translation

    public var canTranslate: Bool {
        translation.canTranslate(session: editor, hasSelectedNote: selectedNote != nil, viewMode: viewMode)
    }

    public func translateSelection() {
        _ = translation.translateSelection(session: editor)
    }

    public func replaceSelectedText(with replacement: String) {
        if translation.replaceSelection(with: replacement, session: editor) {
            applyEditorChanges()
        }
    }

    public func triggerNativeTranslation() {
        translation.triggerNativeTranslation()
    }

    // MARK: - Insertion

    public func insertTextAtCaret(_ text: String) {
        editor.insertTextAtCaret(text)
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
        let title = editor.selectedText.isEmpty ? nil : editor.selectedText
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
        insertTextIntoEditor(links.joined(separator: "\n\n"))
        editorFocus.request()
    }

    public func insertTextIntoEditor(_ insertion: String) {
        editor.insertTextIntoEditor(insertion)
        applyEditorChanges()
    }

    // MARK: - Status

    public func dismissStatusLater() {
        let message = statusMessage
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }

    // MARK: - Vault lifecycle

    public func openVault(_ url: URL, thenSelect fileName: String? = nil) {
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
        if let fileName {
            if let note = store.notes.first(where: { $0.fileURL.lastPathComponent == fileName }) {
                filter = .all
                select(note.id)
                editorFocus.request()
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

    // MARK: - Publishing

    public var canDeploy: Bool {
        publisher.canDeploy(vault: store.configuration)
    }

    public func publishSite() {
        flushEditor()
        let outcome = publisher.publishSite(vault: store.configuration, notes: store.notes)
        if let artifact = outcome.artifact {
            publisher.reveal(artifact)
        }
        statusMessage = outcome.message
    }

    public func deployToCloudflare() {
        flushEditor()
        let outcome = publisher.deployToCloudflare(vault: store.configuration, notes: store.notes)
        if let log = outcome.clipboardLog {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(log, forType: .string)
        }
        statusMessage = outcome.message
    }

    // MARK: - Reveal and focus

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

    public func revealVault() {
        // J-13d: prefer live bookmark resolution after Finder rename-while-quit.
        // `store.configuration.rootURL` is the snapshot from launch; a rename
        // while quit re-resolves via bookmark data to the new inode path.
        // `VaultBookmark.restore()` re-resolves (or honors BANAL_VAULT) and
        // falls back to the stored URL only for firstRun (nil).
        let live = VaultBookmark.restore() ?? store.configuration.rootURL
        NSWorkspace.shared.activateFileViewerSelecting([live])
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

    // MARK: - Enrichment

    /// Enrich the current note's body via on-device Foundation Models.
    /// Explicit user action only. Undo via NSTextView undo manager.
    public func enrichMarkup() {
        guard selectedNote != nil, !editor.editorText.isEmpty else { return }
        let source = editor.editorText
        Task { @MainActor in
            do {
                guard let enriched = try await enrichment.enrichMarkup(source) else {
                    statusMessage = "No enrichment available."
                    return
                }
                // The editor's undo manager captures the change automatically.
                editor.editorText = enriched
                applyEditorChanges()
                statusMessage = "Markup enriched."
            } catch {
                statusMessage = "Enrichment failed: \(error.localizedDescription)"
            }
        }
    }

    /// Suggest a title for the current note via on-device Foundation Models.
    /// Explicit user action only. Undo via NSTextView undo manager.
    public func suggestTitle() {
        guard selectedNote != nil, !editor.editorText.isEmpty else { return }
        let source = editor.editorText
        Task { @MainActor in
            do {
                guard let title = try await enrichment.suggestTitle(source) else {
                    statusMessage = "No title suggestion available."
                    return
                }
                editor.editorTitle = title
                applyEditorChanges()
                statusMessage = "Title suggested: \(title)"
            } catch {
                statusMessage = "Suggestion failed: \(error.localizedDescription)"
            }
        }
    }

    private func reconcileFilter() {
        if case .folder(let path) = filter, !store.folders.contains(path) {
            filter = .all
        }
    }
}

// MARK: - RecipeContext

extension AppModel: RecipeContext {
    public var bufferText: String {
        editor.editorText
    }

    public func cacheIngredients(_ names: [String], forNoteID noteID: String) {
        guard let note = store.note(id: noteID) else { return }
        store.setCachedIngredients(names, for: noteID, fingerprint: note.contentFingerprint)
    }

    public func showStatus(_ message: String) {
        statusMessage = message
    }
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
