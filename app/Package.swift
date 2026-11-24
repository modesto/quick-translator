// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "QuickTranslator",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "QuickTranslatorCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "QuickTranslator",
            dependencies: ["QuickTranslatorCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "QuickTranslatorCoreTests",
            dependencies: ["QuickTranslatorCore"]
        ),
    ]
)
