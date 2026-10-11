import ArtCore
import Foundation

/// Which rendition of an artwork image to load.
public enum ImageRendition: String, Sendable, CaseIterable {
    /// `images.primary.sm` — 480 px thumbnail for lists and cards behind the top card.
    case small
    /// `images.primary.lg` — the large card/reveal image.
    case large
}

/// Pixel dimensions of an image file.
public struct PixelSize: Sendable, Hashable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// Width ÷ height (1 when the height is not positive).
    public var aspectRatio: Double { height > 0 ? Double(width) / Double(height) : 1 }
}

/// An sRGB colour parsed from `dominant_hex` (`"#RRGGBB"`), components 0…255.
public struct PlaceholderColor: Sendable, Hashable {
    public var red: Int
    public var green: Int
    public var blue: Int

    public init(red: Int, green: Int, blue: Int) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Parses `"#RRGGBB"` (case-insensitive). Returns nil for any other form.
    public init?(hex: String) {
        let bytes = Array(hex.utf8)
        guard bytes.count == 7, bytes[0] == UInt8(ascii: "#") else { return nil }
        func nibble(_ b: UInt8) -> Int? {
            switch b {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): Int(b - UInt8(ascii: "0"))
            case UInt8(ascii: "a")...UInt8(ascii: "f"): Int(b - UInt8(ascii: "a")) + 10
            case UInt8(ascii: "A")...UInt8(ascii: "F"): Int(b - UInt8(ascii: "A")) + 10
            default: nil
            }
        }
        var values: [Int] = []
        for i in stride(from: 1, to: 7, by: 2) {
            guard let hi = nibble(bytes[i]), let lo = nibble(bytes[i + 1]) else { return nil }
            values.append(hi * 16 + lo)
        }
        self.init(red: values[0], green: values[1], blue: values[2])
    }
}

/// What a view needs to lay out and tint an image slot before the pixels are decoded.
public struct ImagePlaceholder: Sendable, Equatable {
    /// Pixel size of the requested rendition (falls back to the other rendition).
    public var pixelSize: PixelSize?
    /// `dominant_hex` as given in the dataset.
    public var dominantHex: String
    /// Parsed `dominant_hex`; nil if malformed.
    public var color: PlaceholderColor?
    /// Point of interest in permille (0…1000) of width/height.
    public var focus: FocusPoint
    /// Accessibility description of the image.
    public var altText: String
}

/// Resolves an artwork's `images.primary.sm/lg.file` names to file URLs inside an images directory.
///
/// In the app that directory is the bundle's `Artworks/` folder reference; in tests it is a plain
/// directory (the repository's `Resources/Artworks`). The locator does not touch the file system.
public struct ImageLocator: Sendable, Hashable {
    /// Directory holding the image files.
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// The file entry for a rendition, if the dataset lists one.
    public func file(for artwork: Artwork, rendition: ImageRendition) -> ImageFile? {
        switch rendition {
        case .small: artwork.image.sm
        case .large: artwork.image.lg
        }
    }

    /// URL of a rendition, falling back to the other rendition when the requested one is absent.
    public func url(for artwork: Artwork, rendition: ImageRendition) -> URL? {
        let fallback: ImageRendition = rendition == .small ? .large : .small
        guard let file = file(for: artwork, rendition: rendition) ?? file(for: artwork, rendition: fallback) else {
            return nil
        }
        return url(forFileNamed: file.file)
    }

    /// URL of a file name relative to `directory`.
    public func url(forFileNamed name: String) -> URL {
        directory.appendingPathComponent(name, isDirectory: false)
    }

    /// Pixel size of a rendition as recorded in the dataset (with the same fallback as `url`).
    public func pixelSize(for artwork: Artwork, rendition: ImageRendition) -> PixelSize? {
        let fallback: ImageRendition = rendition == .small ? .large : .small
        guard let file = file(for: artwork, rendition: rendition) ?? file(for: artwork, rendition: fallback) else {
            return nil
        }
        return PixelSize(width: file.w, height: file.h)
    }

    /// Placeholder metadata (size, dominant colour, focus, alt text) for a rendition.
    public func placeholder(for artwork: Artwork, rendition: ImageRendition) -> ImagePlaceholder {
        ImagePlaceholder(
            pixelSize: pixelSize(for: artwork, rendition: rendition),
            dominantHex: artwork.image.dominantHex,
            color: PlaceholderColor(hex: artwork.image.dominantHex),
            focus: artwork.image.focus,
            altText: artwork.image.altText)
    }
}
