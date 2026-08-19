import Combine
import Foundation

public enum SidebarFilter: Equatable, Hashable, Sendable {
    case all
    case published
    case tag(String)
    case folder(String)
}

public enum NoteStoreError: Error, Equatable, Sendable {
    case vaultNotDirectory(URL)
    case noteNotFound(String)
    case folderNotFound(String)
    case invalidFolderName(String)
    case reservedName(String)
    case folderExists(String)
}

/// Loads, indexes, debounced-writes, and watches a vault of Markdown notes.
@MainActor
public final class NoteStore: ObservableObject {
    @Published public private(set) var notes: [Note] = []
    @Published public private(set) var folderTree: [FolderNode] = []
    @Published public private(set) var configuration: VaultConfiguration
    @Published public private(set) var lastError: String?
    @Published public private(set) var rootMissing = false

    /// When false, FSEvents still detect a vanished notes folder but do not reload note files.
    public var watchesExternalEdits = true

    public let writeDebounceNanoseconds: UInt64

    private let fileManager: FileManager
    private let monitor: DirectoryMonitor?
    private var pendingWrites: [String: Note] = [:]
    private var writeTasks: [String: Task<Void, Never>] = [:]
    private var recentlyWritten: [String: (fingerprint: String, until: Date)] = [:]
    private var isReloading = false

    public init(
        configuration: VaultConfiguration,
        monitor: DirectoryMonitor? = DirectoryMonitor(),
        writeDebounceNanoseconds: UInt64 = 400_000_000,
        fileManager: FileManager = .default
    ) {
        self.configuration = configuration
        self.monitor = monitor
        self.writeDebounceNanoseconds = writeDebounceNanoseconds
        self.fileManager = fileManager
    }

    deinit {
        monitor?.stop()
    }

    public var tags: [String] {
        let set = Set(notes.flatMap(\.tags))
        return set.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public var folders: [String] {
        FolderTree.flatten(folderTree).map(\.id)
    }

    public func notes(matching filter: SidebarFilter, query: String = "", sort: NoteSort = .updated) -> [Note] {
        notes
            .filter { note in
                switch filter {
                case .all:
                    return true
                case .published:
                    return note.published
                case .tag(let tag):
                    return note.tags.contains(tag)
                case .folder(let folder):
                    return note.folder == folder
                }
            }
            .filter { $0.matches(query: query) }
            .sorted { lhs, rhs in
                switch sort {
                case .updated:
                    if lhs.updated == rhs.updated {
                        return lhs.displayTitle.localizedStandardCompare(rhs.displayTitle) == .orderedAscending
                    }
                    return lhs.updated > rhs.updated
                case .created:
                    if lhs.created == rhs.created {
                        return lhs.displayTitle.localizedStandardCompare(rhs.displayTitle) == .orderedAscending
                    }
                    return lhs.created > rhs.created
                case .title:
                    return lhs.displayTitle.localizedStandardCompare(rhs.displayTitle) == .orderedAscending
                }
            }
    }

    public func note(id: String) -> Note? {
        notes.first { $0.id == id }
    }

    public func open() throws {
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: configuration.rootURL.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            throw NoteStoreError.vaultNotDirectory(configuration.rootURL)
        }
        try VaultBootstrap.prepare(configuration, fileManager: fileManager)
        configuration = VaultBootstrap.load(from: configuration.rootURL, fileManager: fileManager)
        rootMissing = false
        try reloadAll()
        startMonitor()
    }

    public func reloadAll() throws {
        isReloading = true
        defer { isReloading = false }
        let urls = try collectNoteURLs()
        var loaded: [Note] = []
        loaded.reserveCapacity(urls.count)
        for url in urls {
            do {
                loaded.append(try NoteIO.load(url: url, vaultURL: configuration.rootURL, fileManager: fileManager))
            } catch {
                lastError = error.localizedDescription
            }
        }
        notes = loaded.sorted { $0.updated > $1.updated }
        refreshFolders()
    }

    public func updateConfiguration(_ next: VaultConfiguration) throws {
        configuration = next
        try VaultBootstrap.save(next, fileManager: fileManager)
    }

    @discardableResult
    public func createNote(title: String = "Untitled", folder: String? = nil, now: Date = Date()) throws -> Note {
        if let folder {
            try ensureFolderExists(folder)
        }
        let slug = uniqueSlug(from: title, now: now, folder: folder)
        let url = configuration.rootURL.appendingPathComponent("\(slug).md")
        var note = Note(
            id: slug,
            fileURL: url,
            title: title,
            body: "\n",
            created: now,
            updated: now,
            tags: [],
            published: false,
            modifiedAt: now
        )
        note = try persistImmediately(note)
        upsert(note)
        refreshFolders()
        return note
    }

    @discardableResult
    public func createFolder(name: String, parent: String? = nil) throws -> FolderNode {
        guard let sanitized = FolderName.sanitize(name) else {
            throw NoteStoreError.invalidFolderName(name)
        }
        if let parent, !folderExists(parent) {
            throw NoteStoreError.folderNotFound(parent)
        }
        let siblings = siblingNames(in: parent)
        let leaf = FolderName.uniqueSibling(base: sanitized, existing: siblings)
        let relative = parent.map { "\($0)/\(leaf)" } ?? leaf
        let url = configuration.rootURL.appendingPathComponent(relative, isDirectory: true)
        if fileManager.fileExists(atPath: url.path) {
            throw NoteStoreError.folderExists(relative)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        refreshFolders()
        return FolderNode(id: relative, name: leaf)
    }

    @discardableResult
    public func renameFolder(id: String, to newName: String) throws -> FolderNode {
        guard let sanitized = FolderName.sanitize(newName) else {
            throw NoteStoreError.invalidFolderName(newName)
        }
        guard folderExists(id) else {
            throw NoteStoreError.folderNotFound(id)
        }
        flush()
        let parent = parentPath(of: id)
        let siblings = siblingNames(in: parent).subtracting([id.split(separator: "/").last.map(String.init) ?? id])
        let leaf = FolderName.uniqueSibling(base: sanitized, existing: siblings)
        let destRelative = parent.map { "\($0)/\(leaf)" } ?? leaf
        if destRelative == id {
            return FolderNode(id: id, name: leaf)
        }
        let source = configuration.rootURL.appendingPathComponent(id, isDirectory: true)
        let dest = configuration.rootURL.appendingPathComponent(destRelative, isDirectory: true)
        if fileManager.fileExists(atPath: dest.path) {
            throw NoteStoreError.folderExists(destRelative)
        }
        try fileManager.moveItem(at: source, to: dest)
        rewriteNoteLocations(prefix: id, to: destRelative)
        refreshFolders()
        return FolderNode(id: destRelative, name: leaf)
    }

    public func trashFolder(id: String) throws {
        guard folderExists(id) else {
            throw NoteStoreError.folderNotFound(id)
        }
        flush()
        let url = configuration.rootURL.appendingPathComponent(id, isDirectory: true)
        var resulting: NSURL?
        try fileManager.trashItem(at: url, resultingItemURL: &resulting)
        notes.removeAll { note in
            note.id == id || note.id.hasPrefix(id + "/") || note.folder == id || (note.folder?.hasPrefix(id + "/") ?? false)
        }
        refreshFolders()
    }

    @discardableResult
    public func moveNote(id: String, toFolder folder: String?) throws -> Note {
        guard var note = note(id: id) else {
            throw NoteStoreError.noteNotFound(id)
        }
        if let folder {
            try ensureFolderExists(folder)
        }
        flush()
        let leaf = (note.id as NSString).lastPathComponent
        let destRelative = folder.map { "\($0)/\(leaf)" } ?? leaf
        if destRelative == note.id { return note }
        var dest = destRelative
        var suffix = 2
        while fileManager.fileExists(atPath: configuration.rootURL.appendingPathComponent("\(dest).md").path) {
            dest = folder.map { "\($0)/\(leaf)-\(suffix)" } ?? "\(leaf)-\(suffix)"
            suffix += 1
        }
        let destURL = configuration.rootURL.appendingPathComponent("\(dest).md")
        try fileManager.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.moveItem(at: note.fileURL, to: destURL)
        writeTasks[id]?.cancel()
        writeTasks.removeValue(forKey: id)
        pendingWrites.removeValue(forKey: id)
        notes.removeAll { $0.id == id }
        note.id = dest
        note.fileURL = destURL
        note = try persistImmediately(note)
        upsert(note)
        refreshFolders()
        return note
    }

    public func update(_ note: Note, debounce: Bool = true) {
        if let existing = self.note(id: note.id),
           existing.title == note.title,
           existing.body == note.body,
           existing.tags == note.tags,
           existing.published == note.published {
            return
        }
        var next = note
        next.updated = Date()
        upsert(next)
        if debounce {
            scheduleWrite(next)
        } else {
            writeTasks[next.id]?.cancel()
            pendingWrites.removeValue(forKey: next.id)
            do {
                let saved = try persistImmediately(next)
                upsert(saved)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    public func setPublished(_ published: Bool, id: String) {
        guard var note = note(id: id) else { return }
        note.published = published
        update(note, debounce: false)
    }

    public func trash(id: String) throws {
        guard let note = note(id: id) else {
            throw NoteStoreError.noteNotFound(id)
        }
        writeTasks[id]?.cancel()
        writeTasks.removeValue(forKey: id)
        pendingWrites.removeValue(forKey: id)
        var resulting: NSURL?
        try fileManager.trashItem(at: note.fileURL, resultingItemURL: &resulting)
        notes.removeAll { $0.id == id }
    }

    public func flush() {
        let pending = pendingWrites
        for (id, task) in writeTasks {
            task.cancel()
            writeTasks.removeValue(forKey: id)
        }
        pendingWrites.removeAll()
        for note in pending.values {
            do {
                let saved = try persistImmediately(note)
                upsert(saved)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    /// Apply an observed filesystem change. Tests can call this without FSEvents.
    public func applyExternalChange(at url: URL) {
        if isReloading { return }
        if !rootExists() {
            rootMissing = true
            notes = []
            folderTree = []
            return
        }
        if rootMissing {
            rootMissing = false
        }
        if !watchesExternalEdits { return }
        let standardized = url.standardizedFileURL
        if standardized.hasDirectoryPath || configuration.isReservedDirectory(standardized) {
            if standardized == configuration.rootURL || configuration.isReservedDirectory(standardized) {
                return
            }
        }
        let looksLikeNote = standardized.pathExtension.lowercased() == "md" || standardized.hasDirectoryPath
        if !looksLikeNote && standardized != configuration.rootURL {
            if standardized.path.contains("/\(standardized.deletingLastPathComponent().lastPathComponent)/") {
                // Non-markdown file: ignore unless it is a directory event covering notes.
            }
        }
        if standardized.pathExtension.lowercased() == "md" {
            handleNoteURLChange(standardized)
            return
        }
        // Directory-level events (renames, mass edits): rescan cheaply.
        do {
            try reloadAll()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Private

    private func rootExists() -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: configuration.rootURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func startMonitor() {
        monitor?.start(url: configuration.rootURL) { [weak self] urls in
            Task { @MainActor in
                guard let self else { return }
                for url in urls {
                    self.applyExternalChange(at: url)
                }
            }
        }
    }

    private func handleNoteURLChange(_ url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            let id = NoteIdentity.id(for: url, vaultURL: configuration.rootURL)
            notes.removeAll { $0.id == id || $0.fileURL.standardizedFileURL == url }
            return
        }
        do {
            let loaded = try NoteIO.load(url: url, vaultURL: configuration.rootURL, fileManager: fileManager)
            if shouldIgnoreExternalWrite(loaded) {
                return
            }
            upsert(loaded)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func shouldIgnoreExternalWrite(_ loaded: Note) -> Bool {
        if let mark = recentlyWritten[loaded.id], mark.until > Date(), mark.fingerprint == loaded.contentFingerprint {
            return true
        }
        if let existing = note(id: loaded.id), existing.contentFingerprint == loaded.contentFingerprint {
            return true
        }
        return false
    }

    private func scheduleWrite(_ note: Note) {
        pendingWrites[note.id] = note
        writeTasks[note.id]?.cancel()
        let delay = writeDebounceNanoseconds
        writeTasks[note.id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self, !Task.isCancelled else { return }
            self.finishWrite(id: note.id)
        }
    }

    private func finishWrite(id: String) {
        guard let note = pendingWrites.removeValue(forKey: id) else { return }
        writeTasks.removeValue(forKey: id)
        do {
            let saved = try persistImmediately(note)
            upsert(saved)
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    private func persistImmediately(_ note: Note) throws -> Note {
        let saved = try NoteIO.write(note, fileManager: fileManager)
        recentlyWritten[saved.id] = (saved.contentFingerprint, Date().addingTimeInterval(1.5))
        return saved
    }

    private func upsert(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
        notes.sort { $0.updated > $1.updated }
    }

    private func uniqueSlug(from title: String, now: Date, folder: String?) -> String {
        let leaf = NoteIdentity.slug(from: title, now: now)
        let base = folder.map { "\($0)/\(leaf)" } ?? leaf
        var candidate = base
        var suffix = 2
        let existing = Set(notes.map(\.id))
        while existing.contains(candidate) || fileManager.fileExists(atPath: configuration.rootURL.appendingPathComponent("\(candidate).md").path) {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }
        return candidate
    }

    private func refreshFolders() {
        folderTree = FolderTree.build(paths: collectFolderPaths())
    }

    private func collectFolderPaths() -> [String] {
        guard let enumerator = fileManager.enumerator(
            at: configuration.rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var paths: [String] = []
        for case let url as URL in enumerator {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            if VaultConfiguration.reservedDirectoryNames.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            let relative = NoteIdentity.id(for: url, vaultURL: configuration.rootURL)
            if !relative.isEmpty {
                paths.append(relative)
            }
        }
        return paths
    }

    private func folderExists(_ id: String) -> Bool {
        var isDirectory: ObjCBool = false
        let url = configuration.rootURL.appendingPathComponent(id, isDirectory: true)
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func ensureFolderExists(_ id: String) throws {
        let parts = id.split(separator: "/").map(String.init)
        for part in parts {
            guard FolderName.sanitize(part) != nil else {
                throw NoteStoreError.invalidFolderName(part)
            }
        }
        let url = configuration.rootURL.appendingPathComponent(id, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        refreshFolders()
    }

    private func siblingNames(in parent: String?) -> Set<String> {
        let dir = parent.map { configuration.rootURL.appendingPathComponent($0, isDirectory: true) } ?? configuration.rootURL
        let names = (try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        return Set(names.filter { url in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }.map(\.lastPathComponent))
    }

    private func parentPath(of id: String) -> String? {
        let parent = (id as NSString).deletingLastPathComponent
        return parent.isEmpty ? nil : parent
    }

    private func rewriteNoteLocations(prefix: String, to replacement: String) {
        for index in notes.indices {
            guard let nextID = FolderPath.remap(notes[index].id, from: prefix, to: replacement) else { continue }
            notes[index].id = nextID
            notes[index].fileURL = configuration.rootURL.appendingPathComponent("\(nextID).md")
        }
    }

    private func collectNoteURLs() throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: configuration.rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var urls: [URL] = []
        for case let url as URL in enumerator {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                if VaultConfiguration.reservedDirectoryNames.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }
            if configuration.isNoteFile(url) {
                urls.append(url)
            }
        }
        return urls
    }
}
