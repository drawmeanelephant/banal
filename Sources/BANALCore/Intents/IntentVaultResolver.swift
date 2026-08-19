import Foundation

public enum IntentVaultError: Error, LocalizedError, Equatable, Sendable {
    case vaultNotFound
    case noteNotFound(String)
    case publishFailed(String)

    public var errorDescription: String? {
        switch self {
        case .vaultNotFound:
            return "No notes folder configured in BANAL."
        case .noteNotFound(let id):
            return "Note \"\(id)\" not found."
        case .publishFailed(let message):
            return "Publish failed: \(message)"
        }
    }
}

public enum IntentVaultResolver {
    @MainActor
    private static var testVaultURL: URL?

    @MainActor
    public static func setTestVaultURL(_ url: URL?) {
        testVaultURL = url
    }

    @MainActor
    public static func resolveVaultURL() throws -> URL {
        if let testVaultURL {
            return testVaultURL
        }
        if let remembered = VaultBookmark.restore() {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: remembered.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return remembered
            }
        }
        let defaultURL = VaultBookmark.defaultVaultURL()
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: defaultURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return defaultURL
        }
        if let created = VaultBookmark.createFolderIfAllowed(defaultURL) {
            return created
        }
        throw IntentVaultError.vaultNotFound
    }

    @MainActor
    public static func loadStore(vaultURL: URL? = nil) throws -> NoteStore {
        let rootURL = try vaultURL ?? resolveVaultURL()
        let config = VaultConfiguration(rootURL: rootURL)
        let store = NoteStore(configuration: config, monitor: nil)
        try store.open()
        return store
    }
}
