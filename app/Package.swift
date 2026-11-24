// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickTranslator",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "QuickTranslator",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
