// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VibeHero",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VibeHero", targets: ["VibeHero"])
    ],
    targets: [
        .executableTarget(
            name: "VibeHero",
            path: "Sources/VibeHero"
        ),
        .testTarget(
            name: "VibeHeroTests",
            dependencies: ["VibeHero"],
            path: "Tests/VibeHeroTests"
        )
    ]
)
