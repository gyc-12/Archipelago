// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Archipelago",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ArchipelagoCore",
            targets: ["ArchipelagoCore"]
        ),
        .executable(
            name: "ArchipelagoHooks",
            targets: ["ArchipelagoHooks"]
        ),
        .executable(
            name: "ArchipelagoSetup",
            targets: ["ArchipelagoSetup"]
        ),
        .executable(
            name: "ArchipelagoApp",
            targets: ["ArchipelagoApp"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1"),
        // Sparkle (auto-update) removed for dev — 二开不需要自动更新，且 GitHub 拉取超时
        // .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
    ],
    targets: [
        .target(
            name: "ArchipelagoCore"
        ),
        .executableTarget(
            name: "ArchipelagoHooks",
            dependencies: ["ArchipelagoCore"]
        ),
        .executableTarget(
            name: "ArchipelagoSetup",
            dependencies: ["ArchipelagoCore"]
        ),
        .executableTarget(
            name: "ArchipelagoApp",
            dependencies: [
                "ArchipelagoCore",
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "ArchipelagoCoreTests",
            dependencies: ["ArchipelagoCore"]
        ),
        .testTarget(
            name: "ArchipelagoAppTests",
            dependencies: ["ArchipelagoApp", "ArchipelagoCore"]
        ),
    ]
)
