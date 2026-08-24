// swift-tools-version: 6.0
import PackageDescription

// UIに一切依存しないロジック層。
// Xcodeを開かなくても `swift test` で回せるようにしてある。
let package = Package(
    name: "SokkouCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "SokkouCore", targets: ["SokkouCore"])
    ],
    targets: [
        .target(name: "SokkouCore"),
        .testTarget(name: "SokkouCoreTests", dependencies: ["SokkouCore"])
    ]
)
