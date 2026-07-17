// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LuminaCut",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LuminaCut", targets: ["LuminaCut"])
    ],
    targets: [
        .executableTarget(
            name: "LuminaCut",
            path: "Sources/LuminaCut"
        )
    ]
)
