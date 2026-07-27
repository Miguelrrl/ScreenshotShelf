// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ScreenshotShelf",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ScreenshotShelf", targets: ["ScreenshotShelf"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.2")
    ],
    targets: [
        .executableTarget(
            name: "ScreenshotShelf",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources"
        )
    ],
    swiftLanguageVersions: [.v5]
)
