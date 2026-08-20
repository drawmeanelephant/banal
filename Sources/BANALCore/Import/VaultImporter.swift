import Foundation

/// Structured summary of an import operation.
public struct ImportResult: Equatable, Sendable {
    public var noteCount: Int
    public var assetCount: Int
    public var notePaths: [String]
    public var assetPaths: [String]
    public var importedNotes: [Note]

    public var totalCount: Int {
        noteCount + assetCount
    }

    public init(
        noteCount: Int = 0,
        assetCount: Int = 0,
        notePaths: [String] = [],
        assetPaths: [String] = [],
        importedNotes: [Note] = []
    ) {
        self.noteCount = noteCount
        self.assetCount = assetCount
        self.notePaths = notePaths
        self.assetPaths = assetPaths
        self.importedNotes = importedNotes
    }

    public var summary: String {
        if totalCount == 0 {
            return "No notes or assets were imported."
        }
        var parts: [String] = []
        if noteCount > 0 {
            parts.append("\(noteCount) \(noteCount == 1 ? "note" : "notes")")
        }
        if assetCount > 0 {
            parts.append("\(assetCount) \(assetCount == 1 ? "asset" : "assets")")
        }
        return "Imported " + parts.joined(separator: " and ") + " into the notes folder."
    }
}

/// Recursively copies note files and assets into a BANAL vault on disk.
/// Disk is the single source of truth: no proprietary database or virtual metadata.
public enum VaultImporter {
    public static let supportedNoteExtensions: Set<String> = [
        "md",
        "markdown",
        "mdown",
        "mkdn",
        "textile",
        "cook",
        "txt",
    ]

    public static let supportedAssetExtensions: Set<String> = [
        "png",
        "jpg",
        "jpeg",
        "gif",
        "webp",
        "svg",
        "heic",
        "tiff",
        "tif",
        "bmp",
        "ico",
        "pdf",
        "avif",
        "mp3",
        "m4a",
        "wav",
        "mp4",
        "mov",
    ]

    public static let skippedDirectoryNames: Set<String> = [
        ".git",
        ".obsidian",
        ".trash",
        ".banal",
        ".publish",
        ".svn",
        ".hg",
        ".idea",
        ".vscode",
        "dist",
        "node_modules",
        ".boris",
        ".boris-cache",
        "DerivedData",
        "__MACOSX",
        ".build",
    ]

    public static let skippedFileExtensions: Set<String> = [
        "exe",
        "dll",
        "dylib",
        "so",
        "bin",
        "class",
        "pyc",
        "o",
        "a",
        "swiftmodule",
        "swp",
        "tmp",
        "DS_Store",
    ]

    /// Imports given files and directories into the target vault.
    @discardableResult
    public static func importItems(
        from urls: [URL],
        into configuration: VaultConfiguration,
        targetFolder: String? = nil,
        fileManager: FileManager = .default
    ) throws -> ImportResult {
        let vaultURL = configuration.rootURL.standardizedFileURL
        let vaultPath = vaultURL.path
        var claimedPaths = Set<String>()
        var importedNotes: [Note] = []
        var notePaths: [String] = []
        var assetPaths: [String] = []

        // Ensure vault and assets directory exist
        try fileManager.createDirectory(at: configuration.assetsURL, withIntermediateDirectories: true)

        if let targetFolder {
            let targetFolderURL = vaultURL.appendingPathComponent(targetFolder, isDirectory: true)
            try fileManager.createDirectory(at: targetFolderURL, withIntermediateDirectories: true)
        }

        for sourceURL in urls {
            let source = sourceURL.standardizedFileURL
            let sourcePath = source.path

            // Guard against importing from within the active vault
            if sourcePath == vaultPath || sourcePath.hasPrefix(vaultPath + "/") {
                if urls.count == 1 {
                    throw NoteStoreError.noteAlreadyInVault
                }
                continue
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: sourcePath, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                try importDirectory(
                    from: source,
                    into: configuration,
                    targetFolder: targetFolder,
                    claimedPaths: &claimedPaths,
                    importedNotes: &importedNotes,
                    notePaths: &notePaths,
                    assetPaths: &assetPaths,
                    fileManager: fileManager
                )
            } else {
                try importSingleFile(
                    from: source,
                    into: configuration,
                    targetFolder: targetFolder,
                    claimedPaths: &claimedPaths,
                    importedNotes: &importedNotes,
                    notePaths: &notePaths,
                    assetPaths: &assetPaths,
                    fileManager: fileManager
                )
            }
        }

        return ImportResult(
            noteCount: notePaths.count,
            assetCount: assetPaths.count,
            notePaths: notePaths,
            assetPaths: assetPaths,
            importedNotes: importedNotes
        )
    }

    // MARK: - Private Helpers

    private static func importSingleFile(
        from source: URL,
        into configuration: VaultConfiguration,
        targetFolder: String?,
        claimedPaths: inout Set<String>,
        importedNotes: inout [Note],
        notePaths: inout [String],
        assetPaths: inout [String],
        fileManager: FileManager
    ) throws {
        let ext = source.pathExtension.lowercased()
        let filename = source.lastPathComponent

        if filename.hasPrefix(".") || skippedFileExtensions.contains(ext) {
            return
        }

        if isNoteExtension(ext) {
            let destinationLeaf = normalizedNoteLeaf(filename)
            let relativePath = uniqueRelativePath(
                forLeaf: destinationLeaf,
                folder: targetFolder,
                claimed: &claimedPaths,
                vaultURL: configuration.rootURL,
                fileManager: fileManager
            )
            let destinationURL = configuration.rootURL.appendingPathComponent(relativePath)
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: source, to: destinationURL)

            do {
                let note = try NoteIO.load(url: destinationURL, vaultURL: configuration.rootURL, fileManager: fileManager)
                importedNotes.append(note)
                notePaths.append(relativePath)
            } catch {
                // If parsing fails, the file still copied; track path
                notePaths.append(relativePath)
            }
        } else if isAssetExtension(ext) {
            let assetFolder = targetFolder ?? "assets"
            let relativePath = uniqueRelativePath(
                forLeaf: filename,
                folder: assetFolder,
                claimed: &claimedPaths,
                vaultURL: configuration.rootURL,
                fileManager: fileManager
            )
            let destinationURL = configuration.rootURL.appendingPathComponent(relativePath)
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: source, to: destinationURL)
            assetPaths.append(relativePath)
        }
    }

    private static func importDirectory(
        from rootSourceDir: URL,
        into configuration: VaultConfiguration,
        targetFolder: String?,
        claimedPaths: inout Set<String>,
        importedNotes: inout [Note],
        notePaths: inout [String],
        assetPaths: inout [String],
        fileManager: FileManager
    ) throws {
        guard let enumerator = fileManager.enumerator(
            at: rootSourceDir,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: []
        ) else {
            return
        }

        let rootPath = rootSourceDir.path

        for case let fileURL as URL in enumerator {
            let standardized = fileURL.standardizedFileURL
            let filename = standardized.lastPathComponent
            let ext = standardized.pathExtension.lowercased()

            // Skip hidden files and directories
            if filename.hasPrefix(".") {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: standardized.path, isDirectory: &isDir), isDir.boolValue {
                    enumerator.skipDescendants()
                }
                continue
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: standardized.path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                if skippedDirectoryNames.contains(filename) {
                    enumerator.skipDescendants()
                }
                continue
            }

            if skippedFileExtensions.contains(ext) {
                continue
            }

            // Determine relative path from rootSourceDir
            var relativeFromSource = standardized.path
            if relativeFromSource.hasPrefix(rootPath) {
                relativeFromSource = String(relativeFromSource.dropFirst(rootPath.count))
            }
            if relativeFromSource.hasPrefix("/") {
                relativeFromSource.removeFirst()
            }

            let subfolderPath: String?
            let sourceLeaf = (relativeFromSource as NSString).lastPathComponent
            let sourceSubdir = (relativeFromSource as NSString).deletingLastPathComponent

            if sourceSubdir.isEmpty {
                subfolderPath = targetFolder
            } else if let targetFolder {
                subfolderPath = "\(targetFolder)/\(sourceSubdir)"
            } else {
                subfolderPath = sourceSubdir
            }

            let isInsideAssetsDir = sourceSubdir == "assets" || sourceSubdir.hasPrefix("assets/") ||
                                   sourceSubdir == "attachments" || sourceSubdir.hasPrefix("attachments/") ||
                                   sourceSubdir == "images" || sourceSubdir.hasPrefix("images/")

            if isNoteExtension(ext) {
                let destinationLeaf = normalizedNoteLeaf(sourceLeaf)
                let relativePath = uniqueRelativePath(
                    forLeaf: destinationLeaf,
                    folder: subfolderPath,
                    claimed: &claimedPaths,
                    vaultURL: configuration.rootURL,
                    fileManager: fileManager
                )
                let destinationURL = configuration.rootURL.appendingPathComponent(relativePath)
                try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.copyItem(at: standardized, to: destinationURL)

                do {
                    let note = try NoteIO.load(url: destinationURL, vaultURL: configuration.rootURL, fileManager: fileManager)
                    importedNotes.append(note)
                    notePaths.append(relativePath)
                } catch {
                    notePaths.append(relativePath)
                }
            } else if isAssetExtension(ext) || isInsideAssetsDir {
                let relativePath = uniqueRelativePath(
                    forLeaf: sourceLeaf,
                    folder: subfolderPath,
                    claimed: &claimedPaths,
                    vaultURL: configuration.rootURL,
                    fileManager: fileManager
                )
                let destinationURL = configuration.rootURL.appendingPathComponent(relativePath)
                try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.copyItem(at: standardized, to: destinationURL)
                assetPaths.append(relativePath)
            }
        }
    }

    private static func isNoteExtension(_ ext: String) -> Bool {
        supportedNoteExtensions.contains(ext.lowercased())
    }

    private static func isAssetExtension(_ ext: String) -> Bool {
        supportedAssetExtensions.contains(ext.lowercased())
    }

    private static func normalizedNoteLeaf(_ leaf: String) -> String {
        let ext = (leaf as NSString).pathExtension.lowercased()
        let stem = (leaf as NSString).deletingPathExtension
        if ext == "txt" || ext == "markdown" || ext == "mdown" || ext == "mkdn" {
            return "\(stem).md"
        }
        return leaf
    }

    private static func uniqueRelativePath(
        forLeaf leaf: String,
        folder: String?,
        claimed: inout Set<String>,
        vaultURL: URL,
        fileManager: FileManager
    ) -> String {
        let base = folder.map { "\($0)/\(leaf)" } ?? leaf
        var candidate = base
        var suffix = 2
        let stem = (leaf as NSString).deletingPathExtension
        let ext = (leaf as NSString).pathExtension

        while claimed.contains(candidate) || fileManager.fileExists(atPath: vaultURL.appendingPathComponent(candidate).path) {
            let leafWithSuffix = ext.isEmpty ? "\(stem)-\(suffix)" : "\(stem)-\(suffix).\(ext)"
            candidate = folder.map { "\($0)/\(leafWithSuffix)" } ?? leafWithSuffix
            suffix += 1
        }

        claimed.insert(candidate)
        return candidate
    }
}
