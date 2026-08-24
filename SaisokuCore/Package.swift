// swift-tools-version: 6.0
import PackageDescription

// UIに一切依存しないロジック層。
// Xcodeを開かなくても `swift test` で回せるようにしてある。
let package = Package(
    name: "SaisokuCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "SaisokuCore", targets: ["SaisokuCore"])
    ],
    targets: [
        .target(name: "SaisokuCore"),
        .testTarget(name: "SaisokuCoreTests", dependencies: ["SaisokuCore"])
    ]
)
