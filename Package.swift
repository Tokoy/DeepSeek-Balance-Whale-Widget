// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "DeepSeekBalance",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "DeepSeekBalance", path: "Sources/DeepSeekBalance")
    ]
)
