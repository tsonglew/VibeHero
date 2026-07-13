// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotchHero",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NotchHero", targets: ["NotchHero"])
    ],
    targets: [
        .executableTarget(
            name: "NotchHero",
            path: "Sources/NotchHero"
        )
    ]
)
