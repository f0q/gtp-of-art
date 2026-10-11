import Foundation

/// Paths resolved from this file's location (Packages/ArtDesign/Tests/ArtDesignTests/…).
enum RepoPaths {
    static let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    static let packageDir = testsDir.deletingLastPathComponent().deletingLastPathComponent()
    static let repoRoot = packageDir.deletingLastPathComponent().deletingLastPathComponent()
    static let tokensJSON = repoRoot.appendingPathComponent("Design/Tokens.json")
    static let generator = repoRoot.appendingPathComponent("Design/gen_tokens.py")
    static let designFonts = repoRoot.appendingPathComponent("Design/Fonts")
    static let generatedSwift = packageDir.appendingPathComponent("Sources/ArtDesign/Generated/Tokens.swift")
    static let packageFonts = packageDir.appendingPathComponent("Sources/ArtDesign/Resources/Fonts")
}

/// Minimal typed access to Tokens.json.
struct TokensDocument {
    let root: [String: Any]

    init() throws {
        let data = try Data(contentsOf: RepoPaths.tokensJSON)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        root = obj
    }

    func node(_ path: String) -> Any? {
        path.split(separator: ".").reduce(root as Any?) { node, key in
            (node as? [String: Any])?[String(key)]
        }
    }

    /// "#RRGGBB" for a colour token in `mode` ("dark" = $value, "light" = modes extension).
    func hex(_ path: String, mode: String) -> String? {
        guard let token = node(path) as? [String: Any] else { return nil }
        let value: Any? = mode == "dark"
            ? token["$value"]
            : ((token["$extensions"] as? [String: Any])?["app.artprice.modes"] as? [String: Any])?["light"]
        return (value as? [String: Any])?["hex"] as? String
    }
}

/// WCAG 2.x relative luminance and contrast ratio.
enum WCAG {
    static func luminance(hex: String) -> Double {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let v = UInt32(s, radix: 16) ?? 0
        func channel(_ shift: UInt32) -> Double {
            let c = Double((v >> shift) & 0xFF) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    static func contrast(_ a: String, _ b: String) -> Double {
        let la = luminance(hex: a), lb = luminance(hex: b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
