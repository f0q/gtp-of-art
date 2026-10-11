/// Per-artwork taste features (`artworks[].taste`). Scalar features are integers 0…100.
public struct TasteFeatures: Codable, Sendable, Equatable {
    /// One of `pre1500, 1500_1600, 1600_1700, 1700_1800, 1800_1850, 1850_1900, 1900_1930`.
    public var eraBucket: String
    /// One of `portrait, figure, landscape, still_life, religious_myth, genre, abstract`.
    public var subject: String
    /// One of `serene, dramatic, melancholic, joyful`.
    public var mood: String
    public var abstraction: Int
    public var warmth: Int
    public var saturation: Int
    public var brightness: Int
    public var complexity: Int

    public init(
        eraBucket: String, subject: String, mood: String, abstraction: Int, warmth: Int,
        saturation: Int, brightness: Int, complexity: Int
    ) {
        self.eraBucket = eraBucket
        self.subject = subject
        self.mood = mood
        self.abstraction = abstraction
        self.warmth = warmth
        self.saturation = saturation
        self.brightness = brightness
        self.complexity = complexity
    }

    enum CodingKeys: String, CodingKey {
        case eraBucket = "era_bucket"
        case subject, mood, abstraction, warmth, saturation, brightness, complexity
    }

    /// Era bucket for a year: `<1500 → pre1500`, then centuries to 1800, half-centuries to 1900,
    /// and `≥1900 → 1900_1930`.
    public static func eraBucket(forYear year: Int) -> String {
        switch year {
        case ..<1500: return "pre1500"
        case ..<1600: return "1500_1600"
        case ..<1700: return "1600_1700"
        case ..<1800: return "1700_1800"
        case ..<1850: return "1800_1850"
        case ..<1900: return "1850_1900"
        default: return "1900_1930"
        }
    }
}
