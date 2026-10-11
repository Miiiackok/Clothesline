// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Clothesline",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "ClotheslineCore"),
        .executableTarget(name: "Clothesline", dependencies: ["ClotheslineCore"]),
        .testTarget(name: "ClotheslineCoreTests", dependencies: ["ClotheslineCore"]),
    ]
)
