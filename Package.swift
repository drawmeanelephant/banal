// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BANAL",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "BANALCore", targets: ["BANALCore"]),
        .library(name: "BANALPublisher", targets: ["BANALPublisher"]),
        .library(name: "BANALAppModel", targets: ["BANALAppModel"]),
        .executable(name: "banal-cli", targets: ["BANALApp"]),
        .executable(name: "banal", targets: ["BANALCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "BANALCore",
            path: "Sources/BANALCore"
        ),
        .target(
            name: "BANALPublisher",
            dependencies: ["BANALCore"],
            path: "Sources/BANALPublisher"
        ),
        .target(
            name: "BANALAppModel",
            dependencies: ["BANALCore", "BANALPublisher"],
            path: "Sources/BANALAppModel"
        ),
        .executableTarget(
            name: "BANALApp",
            dependencies: ["BANALCore", "BANALPublisher", "BANALAppModel"],
            path: "Sources/BANALApp"
        ),
        .executableTarget(
            name: "BANALCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "BANALCore",
                "BANALPublisher",
            ],
            path: "Sources/BANALCLI"
        ),
        .testTarget(
            name: "BANALCoreTests",
            dependencies: ["BANALCore"],
            path: "Tests/BANALCoreTests"
        ),
        .testTarget(
            name: "BANALPublisherTests",
            dependencies: ["BANALCore", "BANALPublisher"],
            path: "Tests/BANALPublisherTests"
        ),
        .testTarget(
            name: "BANALCLITests",
            dependencies: ["BANALCLI"],
            path: "Tests/BANALCLITests"
        ),
        .testTarget(
            name: "BANALAppModelTests",
            dependencies: ["BANALCore", "BANALAppModel"],
            path: "Tests/BANALAppModelTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
