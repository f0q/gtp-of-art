// swift-tools-version: 6.2
import Foundation
import PackageDescription

/// SwiftUI's macro plugins (`#Preview`, `@Entry`) ship with Xcode only, not with the Command Line
/// Tools. `ART_SWIFTUI_MACROS` is defined when the active developer directory is a full Xcode, so the
/// package builds and tests with `swift build` / `swift test` on a CLT-only Mac and still gets
/// previews and `@Entry` in Xcode. Override with ARTDESIGN_SWIFTUI_MACROS=1 or =0.
let swiftUIMacrosAvailable: Bool = {
    let env = ProcessInfo.processInfo.environment
    if let forced = env["ARTDESIGN_SWIFTUI_MACROS"] { return forced == "1" }
    let developerDir = env["DEVELOPER_DIR"]
        ?? (try? FileManager.default.destinationOfSymbolicLink(atPath: "/var/db/xcode_select_link"))
        ?? "/Applications/Xcode.app/Contents/Developer"
    return !developerDir.contains("CommandLineTools")
}()

var designSettings: [SwiftSetting] = [.defaultIsolation(MainActor.self)]
if swiftUIMacrosAvailable {
    designSettings.append(.define("ART_SWIFTUI_MACROS"))
}

let package = Package(
    name: "ArtDesign",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ArtDesign", targets: ["ArtDesign"]),
    ],
    targets: [
        .target(
            name: "ArtDesign",
            resources: [.copy("Resources/Fonts")],
            swiftSettings: designSettings
        ),
        .testTarget(
            name: "ArtDesignTests",
            dependencies: ["ArtDesign"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
