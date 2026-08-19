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
    @Published public var recipeMode: RecipeMode = .edit
    @Published public var recipeScale: RecipeScale = .one
    @Published public var oliverRecipe: OliverRecipe?
    @Published public var recipeError: String?
    /// Identity for the open buffer. Changes when the user switches notes,
    /// not when a folder rename or move rewrites the path.
    @Published public private(set) var editorSessionID = UUID()

    public let editorFocus = FocusToken()
    /// Last Oliver HTML for the open buffer. Not published — a render
    /// must not rebuild the editor. Later cards read this; this card
    /// only asks the question.
    public private(set) var lastOliverRender: OliverRender?
    private var suppressEditorSync = false
    private var editorDirty = false
    private var loadedFingerprint = ""
    private var warnedDiskFingerprint = ""
    private var cancellables = Set<AnyCancellable>()
    private var sessionRecipeMode: RecipeMode = .edit
    private var recipeGeneration = 0
    private var oliverClient: OliverClient?
    private var oliver: OliverDebounce
    private let recipeQueue = DispatchQueue(label: "dev.drawmeanelephant.banal.recipe", qos: .userInitiated)

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
        self.oliverClient = nil
        self.oliver = OliverDebounce(client: nil)
        bindStore()
        refreshOliver()
    }

    /// Honor the notes folder’s Oliver path without a relaunch.
    public func refreshOliver() {
        let configured = store.configuration.oliverBinaryPath
        _ = CompilerBookmark.access(path: configured, name: "oliver")
        if let url = OliverLocator.resolveRecipeJSON(configured: configured)
            ?? OliverLocator.resolve(configured: configured) {
            let client = OliverClient(binaryURL: url)
            oliverClient = client
            oliver = OliverDebounce(client: client)
        } else {
            oliverClient = nil
            oliver = OliverDebounce(client: nil)
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
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func select(_ id: String?) {
        if id == selectedID { return }
        persistEditor(to: selectedID)
        selectedID = id
        editorSessionID = UUID()
        loadEditor(from: store.note(id: id ?? ""))
    }

    public var listSelection: Binding<String?> {
        Binding(
            get: { [weak self] in self?.selectedID },
            set: { [weak self] in self?.select($0) }
        )
    }

    public var showsRecipeSwitcher: Bool {
        selectedNote?.language == .cooklang
    }

    public func createNote(language: NoteLanguage = .markdown, in folder: String? = nil) {
        do {
            let dest = folder ?? preferences.folderForNewNote(selected: filter)
            let note = try store.createNote(folder: dest, language: language)
            if language == .cooklang {
                sessionRecipeMode = .edit
            }
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
        do {
            let moved = try store.moveNote(id: noteID, toFolder: folder)
            if selectedID == noteID {
                selectedID = moved.id
            }
        } catch {
            statusMessage = error.localizedDescription
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
        guard !suppressEditorSync, var note = selectedNote else { return }
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
        guard editorDirty, let id, var note = store.note(id: id) else { return }
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
            editorDirty = false
        }
    }

    private func reconcileExternalSelection() {
        guard !suppressEditorSync, let id = selectedID else { return }
        let disk = store.note(id: id)
        let bufferMatches = disk.map { $0.title == editorTitle && $0.body == editorText && $0.published == editorPublished } ?? false
        switch ExternalEdit.action(
            selectedStillOnDisk: disk != nil,
            dirty: editorDirty,
            loadedFingerprint: loadedFingerprint,
            diskFingerprint: disk?.contentFingerprint ?? "",
            bufferMatchesDisk: bufferMatches
        ) {
        case .ignore:
            if bufferMatches {
                editorDirty = false
            }
            if let disk { loadedFingerprint = disk.contentFingerprint }
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
        let next = NoteStore(configuration: VaultConfiguration(rootURL: url))
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
        NSWorkspace.shared.activateFileViewerSelecting([store.configuration.rootURL])
    }

    private func reconcileFilter() {
        if case .folder(let path) = filter, !store.folders.contains(path) {
            filter = .all
        }
    }

    public func setRecipeMode(_ mode: RecipeMode) {
        guard selectedNote?.language == .cooklang else { return }
        if recipeMode == mode { return }
        recipeMode = mode
        sessionRecipeMode = mode
        if mode == .read {
            flushEditor()
            oliverRecipe = nil
            recipeError = nil
            askRecipe()
        } else {
            cancelRecipeAsk()
            clearRecipe()
        }
    }

    public func setRecipeScale(_ scale: RecipeScale) {
        guard recipeScale != scale else { return }
        recipeScale = scale
        if recipeMode == .read, selectedNote?.language == .cooklang {
            askRecipe()
        }
    }

    private func loadEditor(from note: Note?) {
        suppressEditorSync = true
        editorTitle = note?.title ?? ""
        editorText = note?.body ?? ""
        editorTags = note?.tags.joined(separator: ", ") ?? ""
        editorPublished = note?.published ?? false
        loadedFingerprint = note?.contentFingerprint ?? ""
        editorDirty = false
        warnedDiskFingerprint = ""
        recipeScale = .one
        suppressEditorSync = false
        if note?.language == .cooklang {
            recipeMode = sessionRecipeMode
            if recipeMode == .read {
                askRecipe()
            } else {
                cancelRecipeAsk()
                clearRecipe()
            }
        } else {
            recipeMode = .edit
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
    }

    private func askRecipe() {
        guard recipeMode == .read, selectedNote?.language == .cooklang else {
            clearRecipe()
            return
        }
        guard let client = oliverClient else {
            oliverRecipe = nil
            recipeError = "This recipe needs Oliver."
            return
        }
        recipeGeneration += 1
        let generation = recipeGeneration
        let source = editorText
        let scale = recipeScale
        let noteID = selectedID
        let apply: @Sendable (Result<OliverRecipe, Error>) -> Void = { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                guard generation == self.recipeGeneration, self.recipeMode == .read, self.selectedID == noteID else { return }
                switch result {
                case .success(let recipe):
                    self.oliverRecipe = recipe
                    self.recipeError = nil
                case .failure:
                    self.oliverRecipe = nil
                    self.recipeError = "This recipe didn’t parse."
                }
            }
        }
        recipeQueue.async { [client] in
            do {
                apply(.success(try client.recipe(source, scale: scale)))
            } catch {
                apply(.failure(error))
            }
        }
    }

    private func cancelRecipeAsk() {
        recipeGeneration += 1
    }

    private func clearRecipe() {
        oliverRecipe = nil
        recipeError = nil
    }
}

public enum RecipeMode: String, Equatable, Hashable, Sendable {
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
