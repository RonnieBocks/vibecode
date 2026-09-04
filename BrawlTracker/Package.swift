// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BrawlTracker",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "BrawlTracker",
            exclude: ["Resources/Icon"],
            resources: [
                .process("Resources/sample_player.json"),
                .copy("Resources/BrawlerIcons"),
                .copy("Resources/UIIcons")
            ]
        ),
        .testTarget(
            name: "BrawlTrackerTests",
            dependencies: ["BrawlTracker"]
        )
    ]
)
