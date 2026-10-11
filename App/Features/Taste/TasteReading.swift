import ArtCore
import ArtData
import Foundation

/// What one swipe session contributed to the reveal: the wall, the edge copy and the wall's cost.
nonisolated struct TasteSessionResult: Equatable, Sendable {
    /// Liked works in swipe order.
    let liked: [Artwork]
    let swipes: Int
    /// The salon hang: up to `maxWall` liked works.
    var wall: [Artwork] { Array(liked.prefix(Self.maxWall)) }
    var edge: TasteEdge? { TasteEdge.of(likes: liked.count, swipes: swipes) }
    /// Liked works that have a usable game price.
    var pricedLiked: [Artwork] { liked.filter { $0.gamePrice != nil } }
    /// Σ adjusted USD of the liked works with a game price; nil if none has one.
    var wallCostUSD: Int64? {
        let prices = liked.compactMap { $0.gamePrice?.usdAdjusted }
        return prices.isEmpty ? nil : prices.reduce(0, +)
    }

    static let maxWall = 7
}

/// Everything the taste reveal and the taste profile screen show, computed from ArtCore's model
/// (`TasteAnalyzer` + `RarityCalculator`) against the bundled baseline. Pure.
nonisolated struct TasteReading: Equatable, Sendable {
    let report: TasteReport
    let rarity: Rarity
    let archetype: Archetype
    /// "You lean toward …" (top-2 positive buckets), if any.
    let leaning: String?
    /// "You tend to pass on …" (strongest negative bucket), if any.
    let avoiding: String?
    /// Swatches from liked works, used to paint the pigment bars.
    let swatches: [Swatch]
    let session: TasteSessionResult?

    init(
        profile: TasteProfile, baseline: TasteBaseline, categoryLabel: (CategoryID) -> String?,
        swatches: [Swatch], session: TasteSessionResult? = nil
    ) {
        let report = TasteAnalyzer.analyze(profile, baseline: baseline)
        self.report = report
        rarity = RarityCalculator.rarity(for: report, baseline: baseline)
        archetype = Archetypes.archetype(report.archetypeID)
        leaning = TasteCopy.leaning(report.contributions, categoryLabel: categoryLabel)
        avoiding = TasteCopy.avoiding(report.contributions, categoryLabel: categoryLabel)
        self.swatches = swatches
        self.session = session
    }

    /// Reading for a dataset (category labels from the taxonomy, palettes from `palettes`).
    init(
        profile: TasteProfile, dataset: any DatasetProviding, liked: [Artwork],
        palettes: PaletteIndex = .bundled, session: TasteSessionResult? = nil
    ) {
        self.init(
            profile: profile, baseline: dataset.tasteBaseline, categoryLabel: { dataset.category($0)?.label },
            swatches: liked.flatMap { palettes.palette(for: $0) }, session: session)
    }

    var swipeCount: Int { report.swipeCount }
    var rarityLine: String { TasteCopy.rarity(rarity, swipeCount: report.swipeCount) }
    /// Edition number, shown once rarity is visible.
    var edition: Int? { rarity.visibility == .hidden ? nil : rarity.editionNumber }

    /// "≈$1.3B", or nil when no liked work has a price.
    var wallCostText: String? {
        session?.wallCostUSD.map { "≈" + PriceFormatter.compactUSD($0) }
    }
}
