import CoreText
import SwiftUI

// MARK: - Registration

/// Registers the bundled Fraunces variable fonts with CoreText (process scope).
///
/// Call `ArtFonts.register()` once at app launch; every `ArtFont` accessor also calls it lazily, so
/// forgetting is harmless. Safe to call repeatedly (main actor).
public enum ArtFonts {
    /// Outcome of a registration attempt for one file.
    public enum FileStatus: Sendable, Equatable {
        case registered
        case alreadyRegistered
        case missing
        case failed(String)
    }

    private static let result: [String: FileStatus] = {
        var statuses: [String: FileStatus] = [:]
        for file in Tokens.Typography.displayFontFiles {
            statuses[file] = registerFile(named: file)
        }
        return statuses
    }()

    /// Registers the fonts (once) and returns the status per file name.
    @discardableResult
    public static func register() -> [String: FileStatus] { result }

    /// `true` when the upright and italic Fraunces faces can be instantiated by PostScript name.
    public static var isAvailable: Bool {
        register()
        return [Tokens.Typography.displayPostScriptName, Tokens.Typography.displayItalicPostScriptName]
            .allSatisfy(isInstalled(postScriptName:))
    }

    /// URL of a bundled font file inside the package resource bundle.
    public static func url(forFile file: String) -> URL? {
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        return Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fonts")
    }

    static func isInstalled(postScriptName: String) -> Bool {
        let font = CTFontCreateWithName(postScriptName as CFString, 12, nil)
        return (CTFontCopyPostScriptName(font) as String) == postScriptName
    }

    private static func registerFile(named file: String) -> FileStatus {
        guard let url = url(forFile: file) else { return .missing }
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            return .registered
        }
        let cfError = error?.takeRetainedValue()
        if let cfError, CFErrorGetCode(cfError) == CTFontManagerError.alreadyRegistered.rawValue {
            return .alreadyRegistered
        }
        return .failed(cfError.map { CFErrorCopyDescription($0) as String } ?? "unknown")
    }
}

// MARK: - Font accessors

/// Fonts for the type scale. Prefer `.artTextStyle(_:)`, which pins the Fraunces variation axes
/// (weight, optical size, softness) exactly; these `Font` accessors exist for places that need a
/// plain `Font` value (e.g. `Text` concatenation) and rely on `Font.custom(_:size:relativeTo:)`.
public enum ArtFont {
    /// Display sizes of the Fraunces scale.
    public enum Display: Sendable {
        /// 40pt, relative to `.largeTitle`. Archetype names and hero titles.
        case xl
        /// 28pt, relative to `.title`. Screen titles.
        case l

        var style: ArtTypeStyle {
            switch self {
            case .xl: Tokens.Typography.displayXL
            case .l: Tokens.Typography.displayL
            }
        }
    }

    /// Fraunces display font that scales with Dynamic Type.
    public static func display(_ size: Display) -> Font { font(for: size.style) }

    /// Fraunces italic for artwork titles (22pt relative to `.title2`).
    public static var titleArt: Font { font(for: Tokens.Typography.titleArt) }

    /// SF Pro Semibold 48pt with monospaced digits for live bids and revealed prices.
    /// Pair with `.contentTransition(.numericText(value:))`.
    public static var priceHero: Font { font(for: Tokens.Typography.priceHero) }

    /// SF Pro body text style.
    public static var body: Font { font(for: Tokens.Typography.body) }

    /// SF Pro label (subheadline, medium) for buttons, chips and options.
    public static var label: Font { font(for: Tokens.Typography.label) }

    /// SF Pro footnote in small caps for provenance lines.
    public static var provenance: Font { font(for: Tokens.Typography.provenance) }

    /// Builds a Dynamic-Type-aware `Font` for any type style.
    public static func font(for style: ArtTypeStyle) -> Font {
        var font: Font
        switch style.family {
        case .display:
            ArtFonts.register()
            let name = style.italic ? Tokens.Typography.displayItalicPostScriptName
                                    : Tokens.Typography.displayPostScriptName
            font = Font.custom(name, size: style.size, relativeTo: style.relativeTo).weight(style.fontWeight)
        case .ui, .numeric:
            font = systemFont(for: style)
        }
        return decorate(font, style)
    }

    /// The system font for a UI/numeric style at its text style; a non-default base size (such as
    /// the 48pt price hero) is expressed by `.artTextStyle(_:)` through `@ScaledMetric`.
    static func systemFont(for style: ArtTypeStyle) -> Font {
        if style.size == defaultSize(of: style.relativeTo) {
            return Font.system(style.relativeTo).weight(style.fontWeight)
        }
        return Font.system(size: style.size, weight: style.fontWeight)
    }

    static func decorate(_ font: Font, _ style: ArtTypeStyle) -> Font {
        var f = font
        if style.italic && style.family != .display { f = f.italic() }
        if style.smallCaps { f = f.lowercaseSmallCaps() }
        if style.monospacedDigit { f = f.monospacedDigit() }
        return f
    }

    /// Fraunces at an exact size with pinned variation axes (`wght`, `opsz`, `SOFT`, `WONK` = 0).
    /// Falls back to `Font.custom` if CoreText cannot apply variations.
    static func variableDisplayFont(_ style: ArtTypeStyle, size: CGFloat) -> Font {
        ArtFonts.register()
        let name = style.italic ? Tokens.Typography.displayItalicPostScriptName
                                : Tokens.Typography.displayPostScriptName
        guard let ctFont = makeVariableCTFont(name: name, style: style, size: size) else {
            return Font.custom(name, fixedSize: size).weight(style.fontWeight)
        }
        return decorate(Font(ctFont), style)
    }

    /// CoreText font for Fraunces with the style's axes applied. Exposed for tests.
    static func makeVariableCTFont(name: String, style: ArtTypeStyle, size: CGFloat) -> CTFont? {
        guard ArtFonts.isInstalled(postScriptName: name) else { return nil }
        var variation: [NSNumber: NSNumber] = [
            NSNumber(value: FontAxis.weight): NSNumber(value: style.weight),
            NSNumber(value: FontAxis.wonky): 0,
        ]
        if let opsz = style.opticalSize { variation[NSNumber(value: FontAxis.opticalSize)] = NSNumber(value: Double(opsz)) }
        if let soft = style.softness { variation[NSNumber(value: FontAxis.softness)] = NSNumber(value: Double(soft)) }
        let attributes: [CFString: Any] = [
            kCTFontNameAttribute: name,
            kCTFontVariationAttribute: variation,
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    /// Default point sizes of the iOS text styles at the Large (default) content size.
    static func defaultSize(of style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
    }
}

/// OpenType variation axis tags as CoreText identifiers.
nonisolated enum FontAxis {
    static let weight: UInt32 = tag("wght")
    static let opticalSize: UInt32 = tag("opsz")
    static let softness: UInt32 = tag("SOFT")
    static let wonky: UInt32 = tag("WONK")

    static func tag(_ s: String) -> UInt32 {
        s.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }
}

// MARK: - View modifier

extension View {
    /// Applies a token type style with Dynamic Type scaling (up to AX5), exact Fraunces axes,
    /// tracking and line spacing.
    public func artTextStyle(_ style: ArtTypeStyle) -> some View {
        modifier(ArtTextStyleModifier(style: style))
    }
}

/// Scales the token size with `@ScaledMetric` relative to the style's text style.
struct ArtTextStyleModifier: ViewModifier {
    let style: ArtTypeStyle
    @ScaledMetric private var size: CGFloat

    init(style: ArtTypeStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        content
            .font(font)
            .tracking(style.tracking)
            .lineSpacing(max(0, (style.lineHeight - 1) * size * 0.5))
    }

    private var font: Font {
        switch style.family {
        case .display:
            ArtFont.variableDisplayFont(style, size: size)
        case .ui, .numeric:
            ArtFont.decorate(Font.system(size: size, weight: style.fontWeight), style)
        }
    }
}
