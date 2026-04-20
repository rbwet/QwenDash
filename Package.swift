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
    targets: [
        .executableTarget(
            name: "QwenDash",
            path: "Sources/QwenDash",
            resources: []
        )
    ]
)
