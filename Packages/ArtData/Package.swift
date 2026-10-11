// swift-tools-version: 6.2
import PackageDescription

// Foundation layer between the pure ArtCore engine and the app: dataset loading + validation,
// profile persistence, the local-day provider, settings and session factories.
//
// The module is nonisolated (no default MainActor isolation); the app wraps these types in its own
// @Observable models. With only the Command Line Tools, run the tests via `make test-data`, which
// adds the Swift Testing framework search paths.

let package = Package(
    name: "ArtData",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ArtData", targets: ["ArtData"]),
    ],
    dependencies: [
        .package(path: "../ArtCore"),
    ],
    targets: [
        .target(
            name: "ArtData",
            dependencies: [.product(name: "ArtCore", package: "ArtCore")]
        ),
        .testTarget(
            name: "ArtDataTests",
            dependencies: ["ArtData", .product(name: "ArtCore", package: "ArtCore")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
