import Foundation

/// Process-wide start/stop for security-scoped URLs.
///
/// Holds one active security-scoped URL per string key.
/// Starting access under an existing key replaces the previous URL and
/// stops accessing it. StopAccessing must use the URL instance that was started.
public enum SecurityScope: Sendable {
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var accessed: [String: URL] = [:]
    }

    private static let state = State()
    public static let notesFolderKey = "notes-folder"

    @discardableResult
    public static func start(_ url: URL, key: String) -> Bool {
        state.lock.lock()
        defer { state.lock.unlock() }
        if state.accessed[key] == url { return true }
        if let previous = state.accessed.removeValue(forKey: key) {
            previous.stopAccessingSecurityScopedResource()
        }
        // Keep this instance: stopAccessing must use the URL we started.
        if url.startAccessingSecurityScopedResource() {
            state.accessed[key] = url
            return true
        }
        return false
    }

    public static func stop(key: String) {
        state.lock.lock()
        defer { state.lock.unlock() }
        state.accessed.removeValue(forKey: key)?.stopAccessingSecurityScopedResource()
    }

    public static func stopAll() {
        state.lock.lock()
        defer { state.lock.unlock() }
        for url in state.accessed.values {
            url.stopAccessingSecurityScopedResource()
        }
        state.accessed.removeAll()
    }
}

/// Remembers the notes folder as an app-scoped bookmark plus a path.
///
/// The bookmark is what sandbox restore needs (`startAccessing`).
/// The path is what the missing-folder picker shows when the bookmark
/// can no longer resolve — we never create that directory.
public enum VaultBookmark {
    public static let bookmarkKey = "banal.vaultBookmark"
    public static let pathKey = "banal.vaultPath"

    public static func overrideURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        let path = environment["BANAL_VAULT"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    public static func save(
        _ url: URL,
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        if overrideURL(environment: environment) != nil { return }
        defaults.set(url.path, forKey: pathKey)
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(data, forKey: bookmarkKey)
        } catch {
            defaults.removeObject(forKey: bookmarkKey)
        }
        _ = SecurityScope.start(url, key: SecurityScope.notesFolderKey)
    }

    public static func restore(
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        if let override = overrideURL(environment: environment) {
            return override
        }
        if let data = defaults.data(forKey: bookmarkKey) {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                _ = SecurityScope.start(url, key: SecurityScope.notesFolderKey)
                if stale {
                    save(url, defaults: defaults, environment: environment)
                }
                return url
            }
        }
        if let path = defaults.string(forKey: pathKey), !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return nil
    }

    public static func endAccess() {
        SecurityScope.stop(key: SecurityScope.notesFolderKey)
    }

    /// Real user home, not the sandbox container. Used only to *name*
    /// `Documents/BANAL Notes`; creating it still requires write access
    /// or the powerbox.
    public static func realHomeDirectory() -> URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            let path = String(cString: dir)
            if !path.isEmpty {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    public static func defaultVaultURL() -> URL {
        realHomeDirectory()
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("BANAL Notes", isDirectory: true)
    }

    /// Create `url` only when we can already write there. Returns nil
    /// instead of pretending a sandboxed create succeeded.
    public static func createFolderIfAllowed(
        _ url: URL,
        fileManager: FileManager = .default
    ) -> URL? {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else { return nil }
            let probe = url.appendingPathComponent(".banal-write-\(UUID().uuidString)")
            try Data().write(to: probe, options: .atomic)
            try fileManager.removeItem(at: probe)
            return url
        } catch {
            return nil
        }
    }
}

/// App-scoped bookmarks for Settings-chosen Boris/Oliver binaries.
/// Paths still live in `.banal/config.json`; the bookmark is how the
/// sandbox keeps executing them after quit.
public enum CompilerBookmark {
    public static func defaultsKey(_ name: String) -> String {
        "banal.compilerBookmark.\(name)"
    }

    public static func save(
        _ url: URL,
        name: String,
        defaults: UserDefaults = .standard
    ) {
        if let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            defaults.set(data, forKey: defaultsKey(name))
        }
        _ = SecurityScope.start(url, key: name)
    }

    @discardableResult
    public static func access(
        path: String?,
        name: String,
        defaults: UserDefaults = .standard
    ) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let expectedURL = URL(fileURLWithPath: path).standardizedFileURL
        if let data = defaults.data(forKey: defaultsKey(name)) {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                if url.standardizedFileURL.path == expectedURL.path {
                    _ = SecurityScope.start(url, key: name)
                    if stale {
                        save(url, name: name, defaults: defaults)
                    }
                    return url
                } else {
                    forget(name: name, defaults: defaults)
                }
            }
        }
        let url = expectedURL
        _ = SecurityScope.start(url, key: name)
        return url
    }

    public static func forget(name: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: defaultsKey(name))
        SecurityScope.stop(key: name)
    }
}
