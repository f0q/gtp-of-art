import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

nonisolated extension SwiftUI.Color {
    /// A colour that resolves to `light` or `dark` with the current appearance.
    ///
    /// Values are packed `0xRRGGBBAA` in sRGB. Only `Tokens.swift` (generated) should call this with
    /// literals; components use the semantic `Tokens.Color` values.
    public static func artDynamic(light: UInt32, dark: UInt32) -> SwiftUI.Color {
        #if canImport(UIKit)
        let ui = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(artRGBA: dark) : UIColor(artRGBA: light)
        }
        return SwiftUI.Color(uiColor: ui)
        #elseif canImport(AppKit)
        let ns = NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua, .vibrantDark, .vibrantLight,
                                                     .accessibilityHighContrastDarkAqua,
                                                     .accessibilityHighContrastAqua]) .map {
                $0 == .darkAqua || $0 == .vibrantDark || $0 == .accessibilityHighContrastDarkAqua
            } ?? false
            return isDark ? NSColor(artRGBA: dark) : NSColor(artRGBA: light)
        }
        return SwiftUI.Color(nsColor: ns)
        #else
        return SwiftUI.Color(artRGBA: dark)
        #endif
    }

    /// A fixed (non-dynamic) sRGB colour from packed `0xRRGGBBAA`.
    public init(artRGBA rgba: UInt32) {
        let c = ArtRGBA(rgba)
        self.init(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: c.alpha)
    }

    /// Parses a dataset `dominant_hex` value ("#RRGGBB" or "RRGGBB") for image placeholders.
    /// Returns `nil` for malformed input. This is data, not design: it is never a token substitute.
    public init?(datasetHex: String) {
        var s = datasetHex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(artRGBA: (v << 8) | 0xFF)
    }
}

/// Unpacked sRGB components of a `0xRRGGBBAA` value.
nonisolated struct ArtRGBA: Sendable, Equatable {
    var red: Double, green: Double, blue: Double, alpha: Double
    init(_ v: UInt32) {
        red = Double((v >> 24) & 0xFF) / 255
        green = Double((v >> 16) & 0xFF) / 255
        blue = Double((v >> 8) & 0xFF) / 255
        alpha = Double(v & 0xFF) / 255
    }
}

#if canImport(UIKit)
nonisolated extension UIColor {
    convenience init(artRGBA v: UInt32) {
        let c = ArtRGBA(v)
        self.init(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
    }
}
#elseif canImport(AppKit)
nonisolated extension NSColor {
    convenience init(artRGBA v: UInt32) {
        let c = ArtRGBA(v)
        self.init(srgbRed: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
    }
}
#endif
