// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AtlasCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "AtlasCore", targets: ["AtlasCore"])],
    targets: [
        .target(name: "AtlasCore", path: "Sources/AtlasCore"),
        .testTarget(name: "AtlasCoreTests", dependencies: ["AtlasCore"], path: "Tests/AtlasCoreTests")
    ]
)
