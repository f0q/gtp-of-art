/// Population like-rate for one bucket.
public struct BucketBaseline: Codable, Sendable, Equatable {
    /// p_d: share of exposures to this bucket that were liked.
    public var pLike: Double
    /// Number of exposures behind the estimate.
    public var n: Int

    public init(pLike: Double, n: Int) {
        self.pLike = pLike
        self.n = n
    }

    enum CodingKeys: String, CodingKey {
        case pLike = "p_like"
        case n
    }
}

/// Distinctiveness (DST) values at fixed percentiles for one swipe-count bucket.
public struct PercentileKnots: Codable, Sendable, Equatable {
    public var p50: Double
    public var p75: Double
    public var p90: Double
    public var p95: Double
    public var p99: Double

    public init(p50: Double, p75: Double, p90: Double, p95: Double, p99: Double) {
        self.p50 = p50
        self.p75 = p75
        self.p90 = p90
        self.p95 = p95
        self.p99 = p99
    }

    /// `(value, percentile)` knots including the origin `(0, 0)`.
    public var points: [(value: Double, percentile: Double)] {
        [(0, 0), (p50, 50), (p75, 75), (p90, 90), (p95, 95), (p99, 99)]
    }
}

/// `taste_baseline.json`: population statistics for the taste/rarity model.
public struct TasteBaseline: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var baselineID: String
    /// Keyed by bucket (`"era:1600_1700"`, `"mood:serene"`, …).
    public var features: [String: BucketBaseline]
    /// Shrinkage strength α (4).
    public var alpha: Double
    /// Keyed `"swipes_10"`, `"swipes_20"`, `"swipes_40"`, `"swipes_80"`.
    public var distinctivenessPercentiles: [String: PercentileKnots]
    /// Share of players per archetype id (sums to 1).
    public var archetypeShares: [String: Double]

    public init(
        schemaVersion: Int, baselineID: String, features: [String: BucketBaseline], alpha: Double,
        distinctivenessPercentiles: [String: PercentileKnots], archetypeShares: [String: Double]
    ) {
        self.schemaVersion = schemaVersion
        self.baselineID = baselineID
        self.features = features
        self.alpha = alpha
        self.distinctivenessPercentiles = distinctivenessPercentiles
        self.archetypeShares = archetypeShares
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case baselineID = "baseline_id"
        case features, alpha
        case distinctivenessPercentiles = "distinctiveness_percentiles"
        case archetypeShares = "archetype_shares"
    }

    /// Swipe counts with percentile tables, ascending (parsed from `swipes_N` keys).
    public var swipeBuckets: [Int] {
        distinctivenessPercentiles.keys.compactMap { key -> Int? in
            guard key.hasPrefix("swipes_") else { return nil }
            return Int(String(key.dropFirst("swipes_".count)))
        }.sorted()
    }
}
