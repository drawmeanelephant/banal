import Foundation

/// App-scoped preferences (UserDefaults). Vault-traveling publish fields stay in `.banal/config.json`.
public struct AppPreferences: Equatable, Sendable {
    public var sort: NoteSort
    public var newNoteLocation: NewNoteLocation
    public var watchExternalEdits: Bool
    public var fontSize: Double
    public var useSerif: Bool
    public var lineHeight: LineHeightSetting
    public var limitLineLength: Bool
    public var spellCheck: Bool
    public var smartQuotes: Bool
    public var openMostRecentOnLaunch: Bool

    public init(
        sort: NoteSort = .updated,
        newNoteLocation: NewNoteLocation = .selectedFolder,
        watchExternalEdits: Bool = true,
        fontSize: Double = 16,
        useSerif: Bool = false,
        lineHeight: LineHeightSetting = .normal,
        limitLineLength: Bool = true,
        spellCheck: Bool = true,
        smartQuotes: Bool = true,
        openMostRecentOnLaunch: Bool = true
    ) {
        self.sort = sort
        self.newNoteLocation = newNoteLocation
        self.watchExternalEdits = watchExternalEdits
        self.fontSize = fontSize
        self.useSerif = useSerif
        self.lineHeight = lineHeight
        self.limitLineLength = limitLineLength
        self.spellCheck = spellCheck
        self.smartQuotes = smartQuotes
        self.openMostRecentOnLaunch = openMostRecentOnLaunch
    }

    public static let `default` = AppPreferences()

    public func folderForNewNote(selected: SidebarFilter) -> String? {
        switch newNoteLocation {
        case .vaultRoot:
            return nil
        case .inbox:
            return "Inbox"
        case .selectedFolder:
            if case .folder(let path) = selected { return path }
            return nil
        }
    }
}

public enum AppPreferencesStore {
    private static let key = "banal.appPreferences"

    public static func load(defaults: UserDefaults = .standard) -> AppPreferences {
        guard let data = defaults.data(forKey: key) else { return .default }
        return (try? JSONDecoder().decode(CodablePrefs.self, from: data))?.make() ?? .default
    }

    public static func save(_ prefs: AppPreferences, defaults: UserDefaults = .standard) {
        let data = try? JSONEncoder().encode(CodablePrefs(prefs))
        defaults.set(data, forKey: key)
    }

    private struct CodablePrefs: Codable {
        var sort: NoteSort
        var newNoteLocation: NewNoteLocation
        var watchExternalEdits: Bool
        var fontSize: Double
        var useSerif: Bool
        var lineHeight: LineHeightSetting
        var limitLineLength: Bool
        var spellCheck: Bool
        var smartQuotes: Bool
        var openMostRecentOnLaunch: Bool

        init(_ prefs: AppPreferences) {
            sort = prefs.sort
            newNoteLocation = prefs.newNoteLocation
            watchExternalEdits = prefs.watchExternalEdits
            fontSize = prefs.fontSize
            useSerif = prefs.useSerif
            lineHeight = prefs.lineHeight
            limitLineLength = prefs.limitLineLength
            spellCheck = prefs.spellCheck
            smartQuotes = prefs.smartQuotes
            openMostRecentOnLaunch = prefs.openMostRecentOnLaunch
        }

        func make() -> AppPreferences {
            AppPreferences(
                sort: sort,
                newNoteLocation: newNoteLocation,
                watchExternalEdits: watchExternalEdits,
                fontSize: fontSize,
                useSerif: useSerif,
                lineHeight: lineHeight,
                limitLineLength: limitLineLength,
                spellCheck: spellCheck,
                smartQuotes: smartQuotes,
                openMostRecentOnLaunch: openMostRecentOnLaunch
            )
        }
    }
}
