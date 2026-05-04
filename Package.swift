// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WhisperDictation",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "WhisperDictation", targets: ["WhisperDictation"])
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "WhisperDictation",
            dependencies: [
                .product(name: "HotKey", package: "HotKey"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/WhisperDictation",
            exclude: ["WhisperDictation.entitlements"]
        )
    ]
)
