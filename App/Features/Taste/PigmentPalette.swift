import ArtCore
import ArtData
import Foundation

/// An sRGB swatch from a work's `palette` (0…255 components).
nonisolated struct Swatch: Equatable, Hashable, Sendable {
    let red: Int
    let green: Int
    let blue: Int

    init(red: Int, green: Int, blue: Int) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init?(hex: String) {
        guard let c = PlaceholderColor(hex: hex) else { return nil }
        self.init(red: c.red, green: c.green, blue: c.blue)
    }

    /// Relative luminance proxy 0…1 (Rec. 709 weights on gamma-encoded values; ordering only).
    var lightness: Double { (0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)) / 255 }

    /// HSV saturation 0…1.
    var saturation: Double {
        let mx = max(red, green, blue)
        let mn = min(red, green, blue)
        return mx == 0 ? 0 : Double(mx - mn) / Double(mx)
    }

    /// Warmth −1 (blue) … +1 (red/orange), from the red–blue balance.
    var warmth: Double { Double(red - blue) / 255 }
}

/// `images.primary.palette` per artwork. ArtCore's `ImageRef` does not decode the palette yet, so
/// the app reads it from `dataset.json` once (falls back to `dominant_hex`).
nonisolated struct PaletteIndex: Sendable {
    let swatches: [ArtworkID: [Swatch]]

    init(swatches: [ArtworkID: [Swatch]]) { self.swatches = swatches }

    /// Decodes `artworks[].images.primary.palette` from dataset JSON; malformed entries are skipped.
    init(datasetJSON data: Data) {
        struct File: Decodable {
            struct Work: Decodable {
                struct Images: Decodable {
                    struct Primary: Decodable { let palette: [String]? }
                    let primary: Primary
                }
                let id: String
                let images: Images
            }
            let artworks: [Work]
        }
        let file = try? JSONDecoder().decode(File.self, from: data)
        var map: [ArtworkID: [Swatch]] = [:]
        for w in file?.artworks ?? [] {
            let list = (w.images.primary.palette ?? []).compactMap(Swatch.init(hex:))
            if !list.isEmpty { map[ArtworkID(w.id)] = list }
        }
        swatches = map
    }

    /// The bundled dataset's palettes.
    static let bundled: PaletteIndex = {
        guard let url = Bundle.main.url(forResource: "dataset", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return PaletteIndex(swatches: [:]) }
        return PaletteIndex(datasetJSON: data)
    }()

    /// Palette of a work, or its dominant colour.
    func palette(for artwork: Artwork) -> [Swatch] {
        if let list = swatches[artwork.id], !list.isEmpty { return list }
        return Swatch(hex: artwork.image.dominantHex).map { [$0] } ?? []
    }
}

/// The four display axes in reveal order.
nonisolated enum TasteAxis: CaseIterable, Sendable {
    case era, form, palette, mood

    var title: String {
        switch self {
        case .era: "Era"
        case .form: "Form"
        case .palette: "Palette"
        case .mood: "Mood"
        }
    }

    /// Word endpoints (− , +).
    var endpoints: (low: String, high: String) {
        switch self {
        case .era: ("Old Masters", "Modern")
        case .form: ("Figurative", "Abstract")
        case .palette: ("Earthy", "Vivid")
        case .mood: ("Serene", "Dramatic")
        }
    }

    func value(_ axes: TasteAxes) -> Double {
        switch self {
        case .era: axes.era
        case .form: axes.form
        case .palette: axes.palette
        case .mood: axes.mood
        }
    }

    /// Marker position 0…1 along the bar for an axis value −1…+1.
    static func position(_ value: Double) -> Double { min(max((value + 1) / 2, 0), 1) }

    /// "Era: leans Modern" style spoken summary.
    func spoken(_ value: Double) -> String {
        let (low, high) = endpoints
        let strength = abs(value)
        if strength < 0.1 { return "\(title): balanced between \(low) and \(high)" }
        let side = value < 0 ? low : high
        let degree = strength > 0.6 ? "strongly " : (strength > 0.3 ? "" : "slightly ")
        return "\(title): \(degree)leans \(side)"
    }

    /// Gradient stops for this axis's pigment bar: the player's swatches ordered along a colour
    /// property matching the axis, thinned to `count` evenly spaced stops (deterministic).
    func stops(from swatches: [Swatch], count: Int = 5) -> [Swatch] {
        let unique = Array(Set(swatches))
        guard !unique.isEmpty else { return [] }
        let key: (Swatch) -> Double
        switch self {
        case .era: key = { -$0.warmth }  // warm old varnish → cooler modern light
        case .form: key = { $0.saturation * 0.5 + $0.lightness * 0.5 }
        case .palette: key = { $0.saturation * 0.7 + $0.lightness * 0.3 }  // earthy → vivid
        case .mood: key = { -$0.lightness }  // serene light → dramatic dark
        }
        let sorted = unique.sorted {
            let a = key($0)
            let b = key($1)
            if a != b { return a < b }
            return ($0.red, $0.green, $0.blue) < ($1.red, $1.green, $1.blue)
        }
        guard sorted.count > count else { return sorted }
        return (0..<count).map { i in sorted[i * (sorted.count - 1) / (count - 1)] }
    }
}
