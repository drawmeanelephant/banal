import Foundation
import UniformTypeIdentifiers

public enum AssetError: LocalizedError, Equatable, Sendable {
    case unsupportedFileType(String)
    case fileNotFound(URL)
    case invalidVault(URL)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let ext):
            return "“.\(ext)” is not a supported image format."
        case .fileNotFound(let url):
            return "The image file at “\(url.path)” was not found."
        case .invalidVault(let url):
            return "“\(url.path)” is not a valid notes folder."
        }
    }
}

/// Manages saving and copying image files into the vault's `assets/` directory.
/// Hard constraint: image bytes are never altered (no resizing, compression, or metadata stripping).
public enum AssetManager: Sendable {
    /// Supported image extensions (case-insensitive).
    public static let supportedExtensions: Set<String> = [
        "png",
        "jpg",
        "jpeg",
        "gif",
        "webp",
        "heic",
        "heif",
        "svg",
        "tiff",
        "tif",
    ]

    /// Supported content types for file pickers (macOS 12+).
    public static let supportedContentTypes: [UTType] = [
        .png,
        .jpeg,
        .gif,
        .webP,
        .heic,
        .svg,
        .tiff,
        .image,
    ]

    /// Checks whether the given URL points to a supported image file.
    public static func isSupportedImage(url: URL) -> Bool {
        if url.hasDirectoryPath { return false }
        return isSupportedImage(pathExtension: url.pathExtension)
    }

    /// Checks whether the given path extension is a supported image extension.
    public static func isSupportedImage(pathExtension: String) -> Bool {
        supportedExtensions.contains(pathExtension.lowercased())
    }

    /// Sanitizes an image filename for clean filesystem and Markdown compatibility.
    /// Replaces spaces and invalid characters with hyphens, collapses repeated hyphens,
    /// and normalizes the extension.
    public static func sanitizeFilename(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "image.png" }

        let ns = trimmed as NSString
        let stem = ns.deletingPathExtension
        let ext = ns.pathExtension.lowercased()

        let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitizedStem = stem.unicodeScalars.map { scalar -> Character in
            if validChars.contains(scalar) {
                return Character(scalar)
            }
            return "-"
        }
        var cleanStem = String(sanitizedStem)
        while cleanStem.contains("--") {
            cleanStem = cleanStem.replacingOccurrences(of: "--", with: "-")
        }
        cleanStem = cleanStem.trimmingCharacters(in: CharacterSet(charactersIn: "-_."))
        if cleanStem.isEmpty {
            cleanStem = "image"
        }

        if ext.isEmpty {
            return cleanStem
        }
        return "\(cleanStem).\(ext)"
    }

    /// Resolves a unique filename in `directoryURL` by appending `-1`, `-2`, etc., if collisions exist.
    public static func uniqueFilename(
        for filename: String,
        in directoryURL: URL,
        fileManager: FileManager = .default
    ) -> String {
        let ns = filename as NSString
        let stem = ns.deletingPathExtension
        let ext = ns.pathExtension
        let extSuffix = ext.isEmpty ? "" : ".\(ext)"

        if !fileManager.fileExists(atPath: directoryURL.appendingPathComponent(filename).path) {
            return filename
        }

        var suffix = 1
        while true {
            let candidate = "\(stem)-\(suffix)\(extSuffix)"
            if !fileManager.fileExists(atPath: directoryURL.appendingPathComponent(candidate).path) {
                return candidate
            }
            suffix += 1
        }
    }

    /// Returns the relative Markdown image tag `![](assets/<filename>)`.
    public static func markdownLink(for filename: String) -> String {
        "![](assets/\(filename))"
    }

    /// Imports an image file into `<vaultURL>/assets/<filename>` unchanged.
    /// Creates the `assets/` directory if missing, avoids collisions, and returns the relative Markdown tag.
    @discardableResult
    public static func importAsset(
        from sourceURL: URL,
        vaultURL: URL,
        fileManager: FileManager = .default
    ) throws -> (filename: String, markdownLink: String) {
        guard isSupportedImage(url: sourceURL) else {
            throw AssetError.unsupportedFileType(sourceURL.pathExtension)
        }
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw AssetError.fileNotFound(sourceURL)
        }

        let assetsURL = vaultURL.appendingPathComponent("assets", isDirectory: true)
        try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)

        let sourceStandardized = sourceURL.standardizedFileURL
        let assetsStandardized = assetsURL.standardizedFileURL

        // If the source is already inside this vault's assets/ directory, reuse it directly
        if sourceStandardized.deletingLastPathComponent().path == assetsStandardized.path {
            let filename = sourceStandardized.lastPathComponent
            return (filename, markdownLink(for: filename))
        }

        let sanitized = sanitizeFilename(sourceURL.lastPathComponent)
        let unique = uniqueFilename(for: sanitized, in: assetsURL, fileManager: fileManager)
        let destinationURL = assetsURL.appendingPathComponent(unique)

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return (unique, markdownLink(for: unique))
    }

    /// Saves raw image data into `<vaultURL>/assets/<filename>`.
    /// Creates the `assets/` directory if missing, avoids collisions, and returns the relative Markdown tag.
    @discardableResult
    public static func saveAsset(
        data: Data,
        originalFilename: String,
        vaultURL: URL,
        fileManager: FileManager = .default
    ) throws -> (filename: String, markdownLink: String) {
        let assetsURL = vaultURL.appendingPathComponent("assets", isDirectory: true)
        try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)

        let sanitized = sanitizeFilename(originalFilename)
        let unique = uniqueFilename(for: sanitized, in: assetsURL, fileManager: fileManager)
        let destinationURL = assetsURL.appendingPathComponent(unique)

        try data.write(to: destinationURL, options: .atomic)
        return (unique, markdownLink(for: unique))
    }
}
