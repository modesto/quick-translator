// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "QuickTranslator",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "QuickTranslator",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
