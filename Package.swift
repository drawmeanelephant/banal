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
        .executable(name: "BANAL", targets: ["BANALApp"]),
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
        .executableTarget(
            name: "BANALApp",
            dependencies: ["BANALCore", "BANALPublisher"],
            path: "Sources/BANALApp"
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
    ],
    swiftLanguageModes: [.v6]
)
