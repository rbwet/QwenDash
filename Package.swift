// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QwenDash",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "QwenDash", targets: ["QwenDash"])
    ],
    dependencies: [
        // On-device speech-to-text (Apple Silicon, CoreML). First run
        // downloads a Whisper model; thereafter works fully offline.
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.18.0"),
        // Tiny Carbon wrapper for global hotkeys that work while the app is
        // in the background.
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "QwenDash",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "HotKey", package: "HotKey"),
            ],
            path: "Sources/QwenDash",
            resources: []
        )
    ]
)
