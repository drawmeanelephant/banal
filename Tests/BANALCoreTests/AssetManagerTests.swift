import XCTest
@testable import BANALCore

final class AssetManagerTests: XCTestCase {
    private var tempVaultURL: URL!
    private var tempSourceURL: URL!
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("BANALAssetManagerTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempVaultURL = tempDir.appendingPathComponent("vault", isDirectory: true)
        tempSourceURL = tempDir.appendingPathComponent("external", isDirectory: true)
        try fileManager.createDirectory(at: tempVaultURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: tempSourceURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempVaultURL {
            try? fileManager.removeItem(at: tempVaultURL.deletingLastPathComponent())
        }
        try super.tearDownWithError()
    }

    func testSupportedImageExtensions() {
        let valid = ["png", "PNG", "jpg", "JPG", "jpeg", "JPEG", "gif", "GIF", "webp", "WEBP", "heic", "HEIC", "tiff", "TIFF", "tif", "TIF"]
        for ext in valid {
            let url = URL(fileURLWithPath: "/tmp/test.\(ext)")
            XCTAssertTrue(AssetManager.isSupportedImage(url: url), "Expected URL with .\(ext) to be supported")
        }

        let invalid = ["txt", "md", "textile", "cook", "swift", "pdf", "docx", "mp4", "zip", ""]
        for ext in invalid {
            let url = URL(fileURLWithPath: "/tmp/test.\(ext)")
            XCTAssertFalse(AssetManager.isSupportedImage(url: url), "Expected URL with .\(ext) to be unsupported")
        }
    }

    func testAssetsDirectory() {
        let assets = AssetManager.assetsDirectory(for: tempVaultURL)
        XCTAssertEqual(assets.lastPathComponent, "assets")
        XCTAssertEqual(assets.deletingLastPathComponent().standardizedFileURL, tempVaultURL.standardizedFileURL)
    }

    func testStoreAssetFromSourceURL() throws {
        let sourceFile = tempSourceURL.appendingPathComponent("document.pdf")
        let testData = "PDF Content".data(using: .utf8)!
        try testData.write(to: sourceFile)

        let record = try AssetManager.storeAsset(from: sourceFile, in: tempVaultURL)

        XCTAssertEqual(record.originalFilename, "document.pdf")
        XCTAssertEqual(record.storedFilename, "document.pdf")
        XCTAssertEqual(record.relativePath, "assets/document.pdf")
        XCTAssertTrue(fileManager.fileExists(atPath: record.fileURL.path))

        let readData = try Data(contentsOf: record.fileURL)
        XCTAssertEqual(readData, testData)
    }

    func testStoreAssetCollisionResolution() throws {
        let sourceFile1 = tempSourceURL.appendingPathComponent("photo.png")
        let data1 = "Image 1".data(using: .utf8)!
        try data1.write(to: sourceFile1)

        let record1 = try AssetManager.storeAsset(from: sourceFile1, in: tempVaultURL)
        XCTAssertEqual(record1.storedFilename, "photo.png")
        XCTAssertEqual(record1.relativePath, "assets/photo.png")

        // Store a second file with the same name
        let sourceFile2 = tempSourceURL.appendingPathComponent("sub").appendingPathComponent("photo.png")
        try fileManager.createDirectory(at: sourceFile2.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data2 = "Image 2".data(using: .utf8)!
        try data2.write(to: sourceFile2)

        let record2 = try AssetManager.storeAsset(from: sourceFile2, in: tempVaultURL)
        XCTAssertEqual(record2.storedFilename, "photo-1.png")
        XCTAssertEqual(record2.relativePath, "assets/photo-1.png")
        XCTAssertTrue(fileManager.fileExists(atPath: record2.fileURL.path))

        // Store a third file
        let record3 = try AssetManager.storeAsset(from: sourceFile2, in: tempVaultURL)
        XCTAssertEqual(record3.storedFilename, "photo-2.png")
        XCTAssertEqual(record3.relativePath, "assets/photo-2.png")
    }

    func testStoreAssetAlreadyInAssetsDirectory() throws {
        let assetsDir = AssetManager.assetsDirectory(for: tempVaultURL)
        try fileManager.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        let existingFile = assetsDir.appendingPathComponent("existing.txt")
        try "Existing".data(using: .utf8)!.write(to: existingFile)

        let record = try AssetManager.storeAsset(from: existingFile, in: tempVaultURL)
        XCTAssertEqual(record.storedFilename, "existing.txt")
        XCTAssertEqual(record.relativePath, "assets/existing.txt")
        XCTAssertEqual(record.fileURL.standardizedFileURL, existingFile.standardizedFileURL)
    }

    func testStoreAssetRawData() throws {
        let data = "Raw byte payload".data(using: .utf8)!
        let record = try AssetManager.storeAsset(data: data, originalFilename: "notes.txt", in: tempVaultURL)

        XCTAssertEqual(record.originalFilename, "notes.txt")
        XCTAssertEqual(record.storedFilename, "notes.txt")
        XCTAssertEqual(record.relativePath, "assets/notes.txt")
        XCTAssertTrue(fileManager.fileExists(atPath: record.fileURL.path))

        let readData = try Data(contentsOf: record.fileURL)
        XCTAssertEqual(readData, data)
    }

    func testFileLinkFormatting() {
        let link1 = AssetManager.fileLink(name: "Annual Report", relativePath: "assets/report.pdf")
        XCTAssertEqual(link1, "[Annual Report](assets/report.pdf)")

        let link2 = AssetManager.fileLink(name: nil, relativePath: "assets/photo-1.png")
        XCTAssertEqual(link2, "[photo-1.png](assets/photo-1.png)")

        let link3 = AssetManager.fileLink(name: "   ", relativePath: "assets/archive.zip")
        XCTAssertEqual(link3, "[archive.zip](assets/archive.zip)")
    }

    func testImageLinkFormatting() {
        let img1 = AssetManager.imageLink(alt: "Diagram", relativePath: "assets/diagram.png")
        XCTAssertEqual(img1, "![Diagram](assets/diagram.png)")

        let img2 = AssetManager.imageLink(alt: "", relativePath: "assets/header.jpg")
        XCTAssertEqual(img2, "![](assets/header.jpg)")
    }
}
