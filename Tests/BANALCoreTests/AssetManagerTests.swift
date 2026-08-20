import XCTest
import UniformTypeIdentifiers
@testable import BANALCore

final class AssetManagerTests: XCTestCase {
    var tempDirectory: URL!
    var vaultURL: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BANALAssetManagerTests-\(UUID().uuidString)")
        vaultURL = tempDirectory.appendingPathComponent("Vault")
        try? FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    func testSupportedImageExtensions() {
        let valid = ["png", "PNG", "jpg", "JPG", "jpeg", "JPEG", "gif", "GIF", "webp", "WEBP", "heic", "HEIC", "heif", "HEIF", "svg", "SVG", "tiff", "TIFF", "tif", "TIF"]
        for ext in valid {
            XCTAssertTrue(AssetManager.isSupportedImage(pathExtension: ext), "Expected .\(ext) to be supported")
            let url = URL(fileURLWithPath: "/tmp/test.\(ext)")
            XCTAssertTrue(AssetManager.isSupportedImage(url: url), "Expected URL with .\(ext) to be supported")
        }

        let invalid = ["txt", "md", "textile", "cook", "swift", "pdf", "docx", "mp4", "zip", ""]
        for ext in invalid {
            XCTAssertFalse(AssetManager.isSupportedImage(pathExtension: ext), "Expected .\(ext) to be unsupported")
            let url = URL(fileURLWithPath: "/tmp/test.\(ext)")
            XCTAssertFalse(AssetManager.isSupportedImage(url: url), "Expected URL with .\(ext) to be unsupported")
        }

        let dirURL = URL(fileURLWithPath: "/tmp/photos.png/", isDirectory: true)
        XCTAssertFalse(AssetManager.isSupportedImage(url: dirURL))
    }

    func testFilenameSanitization() {
        XCTAssertEqual(AssetManager.sanitizeFilename("diagram.png"), "diagram.png")
        XCTAssertEqual(AssetManager.sanitizeFilename("PHOTO.JPG"), "PHOTO.jpg")
        XCTAssertEqual(AssetManager.sanitizeFilename("My Diagram (1) : 2026.PNG"), "My-Diagram-1-2026.png")
        XCTAssertEqual(AssetManager.sanitizeFilename("   foo   bar.webp  "), "foo-bar.webp")
        XCTAssertEqual(AssetManager.sanitizeFilename("recipe---photo--final.heic"), "recipe-photo-final.heic")
        XCTAssertEqual(AssetManager.sanitizeFilename(""), "image.png")
        XCTAssertEqual(AssetManager.sanitizeFilename("???"), "image")
        XCTAssertEqual(AssetManager.sanitizeFilename("???!!!.gif"), "image.gif")
        XCTAssertEqual(AssetManager.sanitizeFilename("..hello..world...png"), "hello-world.png")
    }

    func testMarkdownLinkGeneration() {
        XCTAssertEqual(AssetManager.markdownLink(for: "photo.png"), "![](assets/photo.png)")
        XCTAssertEqual(AssetManager.markdownLink(for: "diagram-1.png"), "![](assets/diagram-1.png)")
        XCTAssertEqual(AssetManager.markdownLink(for: "nested/photo.png"), "![](assets/nested/photo.png)")
    }

    func testUniqueFilenameCollisionHandling() throws {
        let assetsURL = vaultURL.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)

        // When no file exists
        let name1 = AssetManager.uniqueFilename(for: "screenshot.png", in: assetsURL)
        XCTAssertEqual(name1, "screenshot.png")

        // Create screenshot.png
        try "dummy".write(to: assetsURL.appendingPathComponent("screenshot.png"), atomically: true, encoding: .utf8)

        // First collision appends -1
        let name2 = AssetManager.uniqueFilename(for: "screenshot.png", in: assetsURL)
        XCTAssertEqual(name2, "screenshot-1.png")

        // Create screenshot-1.png
        try "dummy".write(to: assetsURL.appendingPathComponent("screenshot-1.png"), atomically: true, encoding: .utf8)

        // Second collision appends -2
        let name3 = AssetManager.uniqueFilename(for: "screenshot.png", in: assetsURL)
        XCTAssertEqual(name3, "screenshot-2.png")
    }

    func testImportAssetCopiesFileAndCreatesDirectory() throws {
        let sourceDir = tempDirectory.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let sourceFile = sourceDir.appendingPathComponent("recipe photo.png")
        let originalBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01, 0x02, 0x03])
        try originalBytes.write(to: sourceFile)

        let result = try AssetManager.importAsset(from: sourceFile, vaultURL: vaultURL)
        XCTAssertEqual(result.filename, "recipe-photo.png")
        XCTAssertEqual(result.markdownLink, "![](assets/recipe-photo.png)")

        let destinationFile = vaultURL.appendingPathComponent("assets/recipe-photo.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))

        // Raw bytes must remain unaltered
        let destinationBytes = try Data(contentsOf: destinationFile)
        XCTAssertEqual(destinationBytes, originalBytes)
    }

    func testImportAssetCollisionRenaming() throws {
        let sourceDir = tempDirectory.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let sourceFile = sourceDir.appendingPathComponent("diagram.png")
        let data = Data([0x01, 0x02, 0x03, 0x04])
        try data.write(to: sourceFile)

        let first = try AssetManager.importAsset(from: sourceFile, vaultURL: vaultURL)
        XCTAssertEqual(first.filename, "diagram.png")
        XCTAssertEqual(first.markdownLink, "![](assets/diagram.png)")

        let second = try AssetManager.importAsset(from: sourceFile, vaultURL: vaultURL)
        XCTAssertEqual(second.filename, "diagram-1.png")
        XCTAssertEqual(second.markdownLink, "![](assets/diagram-1.png)")

        let third = try AssetManager.importAsset(from: sourceFile, vaultURL: vaultURL)
        XCTAssertEqual(third.filename, "diagram-2.png")
        XCTAssertEqual(third.markdownLink, "![](assets/diagram-2.png)")

        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.appendingPathComponent("assets/diagram.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.appendingPathComponent("assets/diagram-1.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: vaultURL.appendingPathComponent("assets/diagram-2.png").path))
    }

    func testImportAssetReuseWhenAlreadyInAssets() throws {
        let assetsURL = vaultURL.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
        let existingFile = assetsURL.appendingPathComponent("existing.png")
        try Data([0xAA, 0xBB]).write(to: existingFile)

        let result = try AssetManager.importAsset(from: existingFile, vaultURL: vaultURL)
        XCTAssertEqual(result.filename, "existing.png")
        XCTAssertEqual(result.markdownLink, "![](assets/existing.png)")
    }

    func testImportAssetInvalidOrMissingFile() throws {
        let missingURL = tempDirectory.appendingPathComponent("missing.png")
        XCTAssertThrowsError(try AssetManager.importAsset(from: missingURL, vaultURL: vaultURL)) { error in
            XCTAssertEqual(error as? AssetError, AssetError.fileNotFound(missingURL))
        }

        let nonImageURL = tempDirectory.appendingPathComponent("document.pdf")
        try Data([0x01]).write(to: nonImageURL)
        XCTAssertThrowsError(try AssetManager.importAsset(from: nonImageURL, vaultURL: vaultURL)) { error in
            XCTAssertEqual(error as? AssetError, AssetError.unsupportedFileType("pdf"))
        }
    }

    func testSaveAssetData() throws {
        let rawData = Data([0x10, 0x20, 0x30, 0x40])
        let result1 = try AssetManager.saveAsset(data: rawData, originalFilename: "captured.png", vaultURL: vaultURL)
        XCTAssertEqual(result1.filename, "captured.png")
        XCTAssertEqual(result1.markdownLink, "![](assets/captured.png)")

        let result2 = try AssetManager.saveAsset(data: rawData, originalFilename: "captured.png", vaultURL: vaultURL)
        XCTAssertEqual(result2.filename, "captured-1.png")
        XCTAssertEqual(result2.markdownLink, "![](assets/captured-1.png)")

        let file1 = vaultURL.appendingPathComponent("assets/captured.png")
        let file2 = vaultURL.appendingPathComponent("assets/captured-1.png")
        XCTAssertEqual(try Data(contentsOf: file1), rawData)
        XCTAssertEqual(try Data(contentsOf: file2), rawData)
    }
}
