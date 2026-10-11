/// How much of the rarity result the UI may show.
public enum RarityVisibility: String, Codable, Sendable {
    /// Fewer than 12 swipes: show nothing.
    case hidden
    /// 12…39 swipes: show only the band.
    case band
    /// 40+ swipes: show the percentile.
    case exact
}

/// Percentile band `[lower, upper)` (the top band is `[99, 100]`).
public struct RarityBand: Codable, Sendable, Equatable {
    public var lower: Int
    public var upper: Int
    public init(lower: Int, upper: Int) {
        self.lower = lower
        self.upper = upper
    }
}

/// Display-only rarity ("estimated" in the UI).
public struct Rarity: Sendable, Equatable {
    public var visibility: RarityVisibility
    /// Swipe-count bucket whose percentile table was used.
    public var swipeBucket: Int?
    /// "Rarer than Y% of players" (0…99). Always computed; respect `visibility` when showing it.
    public var percentile: Double
    public var band: RarityBand
    public var archetypeID: String
    /// "About X% share your archetype" (0…1), from the baseline; nil if unknown.
    public var archetypeShare: Double?
    /// "Edition N / 100": round(share·100) clamped to 1…100.
    public var editionNumber: Int?

    public init(
        visibility: RarityVisibility, swipeBucket: Int?, percentile: Double, band: RarityBand, archetypeID: String,
        archetypeShare: Double?, editionNumber: Int?
    ) {
        self.visibility = visibility
        self.swipeBucket = swipeBucket
        self.percentile = percentile
        self.band = band
        self.archetypeID = archetypeID
        self.archetypeShare = archetypeShare
        self.editionNumber = editionNumber
    }
}

/// Rarity from the distinctiveness percentile tables and archetype frequencies.
public enum RarityCalculator {
    public static let hiddenBelowSwipes = 12
    public static let exactFromSwipes = 40
    public static let bandBounds = [0, 50, 75, 90, 95, 99, 100]

    /// Visibility for a swipe count.
    public static func visibility(swipeCount: Int) -> RarityVisibility {
        swipeCount < hiddenBelowSwipes ? .hidden : (swipeCount < exactFromSwipes ? .band : .exact)
    }

    /// The bucket in `buckets` nearest to `swipes` (ties → the smaller bucket).
    public static func nearestBucket(swipes: Int, buckets: [Int]) -> Int? {
        var best: Int?
        for b in buckets.sorted() {
            if let current = best {
                if abs(b - swipes) < abs(current - swipes) { best = b }
            } else {
                best = b
            }
        }
        return best
    }

    /// Linear interpolation of `dst` through `(0,0), (p50,50), …, (p99,99)`; ≥ p99 → 99.
    /// A zero-width segment yields its upper percentile.
    public static func percentile(dst: Double, knots: PercentileKnots) -> Double {
        let pts = knots.points
        if dst <= 0 { return 0 }
        for i in 1..<pts.count where dst <= pts[i].value {
            let lo = pts[i - 1]
            let hi = pts[i]
            let width = hi.value - lo.value
            if width <= 0 { return hi.percentile }
            return lo.percentile + (hi.percentile - lo.percentile) * (dst - lo.value) / width
        }
        return 99
    }

    /// The band containing `percentile`.
    public static func band(percentile: Double) -> RarityBand {
        for i in stride(from: bandBounds.count - 2, through: 0, by: -1) where percentile >= Double(bandBounds[i]) {
            return RarityBand(lower: bandBounds[i], upper: bandBounds[i + 1])
        }
        return RarityBand(lower: 0, upper: 50)
    }

    /// Rarity for raw inputs.
    public static func rarity(dst: Double, swipeCount: Int, archetypeID: String, baseline: TasteBaseline) -> Rarity {
        let bucket = nearestBucket(swipes: swipeCount, buckets: baseline.swipeBuckets)
        let knots = bucket.flatMap { baseline.distinctivenessPercentiles["swipes_\($0)"] }
        let pct = knots.map { percentile(dst: dst, knots: $0) } ?? 0
        let share = baseline.archetypeShares[archetypeID]
        let edition = share.map { min(max(Int(($0 * 100).rounded()), 1), 100) }
        return Rarity(
            visibility: visibility(swipeCount: swipeCount), swipeBucket: bucket, percentile: pct,
            band: band(percentile: pct), archetypeID: archetypeID, archetypeShare: share, editionNumber: edition)
    }

    /// Rarity for a taste report.
    public static func rarity(for report: TasteReport, baseline: TasteBaseline) -> Rarity {
        rarity(dst: report.distinctiveness, swipeCount: report.swipeCount, archetypeID: report.archetypeID, baseline: baseline)
    }
}
