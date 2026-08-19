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
    private let oliver: OliverDebounce

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
        self.oliver = OliverDebounce()
        bindStore()
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
        loadEditor(from: store.note(id: id ?? ""))
    }

    public var listSelection: Binding<String?> {
        Binding(
            get: { [weak self] in self?.selectedID },
            set: { [weak self] in self?.select($0) }
        )
    }

    public func createNote(in folder: String? = nil) {
        do {
            let dest = folder ?? preferences.folderForNewNote(selected: filter)
            let note = try store.createNote(folder: dest)
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
        do {
            try store.updateConfiguration(store.configuration)
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
        let next = NoteStore(configuration: VaultConfiguration(rootURL: url))
        next.watchesExternalEdits = preferences.watchExternalEdits
        store = next
        bindStore()
        needsVault = false
        missingNotesFolder = false
        VaultBookmark.save(url)
        bootstrap()
    }

    public func publishSite() {
        flushEditor()
        let vault = store.configuration
        let configuration = PublishConfiguration.default(for: vault)
        let publisher = BANALPublisher.make(configuration: configuration)
        do {
            let result = try publisher.publish(notes: store.notes, vault: vault, configuration: configuration)
            lastPublishResult = result
            let engine = result.usedBorisBinary ? "Boris" : "builtin"
            statusMessage = "Published \(result.compiledNoteIDs.count) notes with \(engine) → \(result.artifactDirectory.path)"
            NSWorkspace.shared.activateFileViewerSelecting([result.artifactDirectory])
        } catch PublishError.noPublishedNotes {
            statusMessage = "Nothing published."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func revealVault() {
        NSWorkspace.shared.activateFileViewerSelecting([store.configuration.rootURL])
    }

    private func reconcileFilter() {
        if case .folder(let path) = filter, !store.folders.contains(path) {
            filter = .all
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
        suppressEditorSync = false
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
        oliver.schedule(source: editorText) { [weak self] render in
            Task { @MainActor [weak self] in
                guard let self, self.selectedID == noteID else { return }
                self.lastOliverRender = render
            }
        }
    }
}

public final class FocusToken {
    public var handler: (() -> Void)?
    public func request() { handler?() }
}

public enum VaultBookmark {
    private static let key = "banal.vaultBookmark"

    public static func overrideURL() -> URL? {
        let path = ProcessInfo.processInfo.environment["BANAL_VAULT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    public static func save(_ url: URL) {
        if overrideURL() != nil { return }
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            UserDefaults.standard.set(url.path, forKey: "banal.vaultPath")
        }
    }

    public static func restore() -> URL? {
        if let override = overrideURL() { return override }
        if let data = UserDefaults.standard.data(forKey: key) {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                _ = url.startAccessingSecurityScopedResource()
                if stale {
                    save(url)
                }
                return url
            }
        }
        if let path = UserDefaults.standard.string(forKey: "banal.vaultPath") {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    public static func defaultVaultURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("BANAL Notes", isDirectory: true)
    }
}

extension NoteStore {
    fileprivate func monitorStopForReplacement() {
        flush()
    }
}
