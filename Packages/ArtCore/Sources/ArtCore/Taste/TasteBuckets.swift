/// Feature buckets used by the taste model. Every artwork falls in exactly one bucket of each of
/// the nine families, keyed `"<family>:<value>"`.
public enum TasteBuckets {
    /// Bucket families in canonical order.
    public static let families = [
        "era", "category", "subject", "abstraction", "warmth", "saturation", "brightness", "complexity", "mood",
    ]

    /// Level names per scalar family (low, mid, high).
    public static let levelNames: [String: [String]] = [
        "abstraction": ["low", "mid", "high"],
        "warmth": ["cool", "neutral", "warm"],
        "saturation": ["muted", "mid", "vivid"],
        "brightness": ["dark", "mid", "light"],
        "complexity": ["sparse", "mid", "busy"],
    ]

    /// Tercile of a 0…100 value: 0–33 → 0, 34–66 → 1, 67–100 → 2 (values outside are clamped).
    public static func level(_ value: Int) -> Int {
        value <= 33 ? 0 : (value <= 66 ? 1 : 2)
    }

    /// The nine bucket keys of a work, in `families` order.
    public static func buckets(for features: TasteFeatures, category: CategoryID) -> [String] {
        func scalar(_ family: String, _ value: Int) -> String {
            family + ":" + levelNames[family]![level(value)]
        }
        return [
            "era:" + features.eraBucket,
            "category:" + category.rawValue,
            "subject:" + features.subject,
            scalar("abstraction", features.abstraction),
            scalar("warmth", features.warmth),
            scalar("saturation", features.saturation),
            scalar("brightness", features.brightness),
            scalar("complexity", features.complexity),
            "mood:" + features.mood,
        ]
    }

    /// Buckets of an artwork (primary category).
    public static func buckets(for artwork: Artwork) -> [String] {
        buckets(for: artwork.taste, category: artwork.category)
    }
}
