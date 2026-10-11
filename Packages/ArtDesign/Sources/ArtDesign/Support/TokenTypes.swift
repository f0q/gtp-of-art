import SwiftUI

/// Which font family a type style draws from.
nonisolated public enum ArtFontFamily: Sendable, Equatable {
    /// Fraunces (bundled variable font).
    case display
    /// SF Pro via system text styles.
    case ui
    /// System font with monospaced digits.
    case numeric
}

/// One entry of the type scale, generated from `font.style.*` in Tokens.json.
nonisolated public struct ArtTypeStyle: Sendable, Equatable {
    /// Font family.
    public let family: ArtFontFamily
    /// Base point size at the default Dynamic Type size.
    public let size: CGFloat
    /// CSS-style weight (100...900).
    public let weight: Int
    /// System text style the size scales with.
    public let relativeTo: Font.TextStyle
    /// Line height as a multiple of the font size.
    public let lineHeight: Double
    /// Letter spacing in points.
    public let tracking: CGFloat
    /// Italic face.
    public let italic: Bool
    /// Lowercase rendered as small caps.
    public let smallCaps: Bool
    /// Tabular (monospaced) digits.
    public let monospacedDigit: Bool
    /// Fraunces `opsz` axis value, if pinned.
    public let opticalSize: CGFloat?
    /// Fraunces `SOFT` axis value, if pinned.
    public let softness: CGFloat?

    /// Creates a type style. Normally only `Tokens.swift` calls this.
    public init(family: ArtFontFamily, size: CGFloat, weight: Int, relativeTo: Font.TextStyle,
                lineHeight: Double, tracking: CGFloat, italic: Bool, smallCaps: Bool,
                monospacedDigit: Bool, opticalSize: CGFloat?, softness: CGFloat?) {
        self.family = family
        self.size = size
        self.weight = weight
        self.relativeTo = relativeTo
        self.lineHeight = lineHeight
        self.tracking = tracking
        self.italic = italic
        self.smallCaps = smallCaps
        self.monospacedDigit = monospacedDigit
        self.opticalSize = opticalSize
        self.softness = softness
    }

    /// SwiftUI weight closest to `weight`.
    public var fontWeight: Font.Weight {
        switch weight {
        case ..<150: .ultraLight
        case ..<250: .thin
        case ..<350: .light
        case ..<450: .regular
        case ..<550: .medium
        case ..<650: .semibold
        case ..<750: .bold
        case ..<850: .heavy
        default: .black
        }
    }
}

/// A drop shadow token.
nonisolated public struct ArtShadow: Sendable {
    /// Shadow colour (already includes its opacity per appearance).
    public let color: Color
    /// Horizontal offset in points.
    public let x: CGFloat
    /// Vertical offset in points.
    public let y: CGFloat
    /// Design-tool blur in points. SwiftUI's `shadow(radius:)` takes roughly half of this.
    public let blur: CGFloat

    /// Creates a shadow token. Normally only `Tokens.swift` calls this.
    public init(color: Color, x: CGFloat, y: CGFloat, blur: CGFloat) {
        self.color = color
        self.x = x
        self.y = y
        self.blur = blur
    }
}

extension View {
    /// Applies a shadow token.
    public func artShadow(_ shadow: ArtShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.blur / 2, x: shadow.x, y: shadow.y)
    }
}
