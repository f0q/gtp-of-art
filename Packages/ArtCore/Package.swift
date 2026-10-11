// swift-tools-version: 6.2
import PackageDescription

// Tests use Swift Testing. On a Mac with only the Command Line Tools (no Xcode), run them via
// `Packages/ArtCore/Scripts/test.sh` — see the comment in that script for why.

let package = Package(
    name: "ArtCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ArtCore", targets: ["ArtCore"]),
    ],
    targets: [
        // Pure game logic. Standard library only: no Foundation, no platform math.
        .target(name: "ArtCore"),
        // Codable fixture shapes + JSON I/O shared by FixtureGen and the tests (Foundation allowed).
        .target(name: "FixtureKit", dependencies: ["ArtCore"]),
        // `swift run --package-path Packages/ArtCore FixtureGen spec/fixtures`
        .executableTarget(name: "FixtureGen", dependencies: ["ArtCore", "FixtureKit"]),
        .testTarget(name: "ArtCoreTests", dependencies: ["ArtCore", "FixtureKit"]),
    ],
    swiftLanguageModes: [.v6]
)
