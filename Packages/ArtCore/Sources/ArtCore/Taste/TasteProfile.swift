/// One like/pass decision as applied to the taste profile.
public struct TasteSwipe: Codable, Sendable, Equatable {
    public var artworkID: ArtworkID
    public var buckets: [String]
    public var liked: Bool

    public init(artworkID: ArtworkID, buckets: [String], liked: Bool) {
        self.artworkID = artworkID
        self.buckets = buckets
        self.liked = liked
    }

    public init(artwork: Artwork, liked: Bool) {
        self.init(artworkID: artwork.id, buckets: TasteBuckets.buckets(for: artwork), liked: liked)
    }

    enum CodingKeys: String, CodingKey {
        case artworkID = "artwork_id"
        case buckets, liked
    }
}

/// Persisted taste counts: per bucket `exposures` (S_d, swipes seen) and `likes` (L_d).
/// Integer counts, so `undoing` exactly inverts `applying`. Zero counts are removed.
/// Onboarding seeds (`seeded(from:)`) add pseudo-counts recorded in `seeds`; undo never removes them.
public struct TasteProfile: Codable, Sendable, Equatable {
    public var swipeCount: Int
    public var likeCount: Int
    public var exposures: [String: Int]
    public var likes: [String: Int]
    /// Pseudo-exposures (= pseudo-likes) per bucket from the onboarding prior; included in
    /// `exposures` and `likes`.
    public var seeds: [String: Int]

    public init(
        swipeCount: Int = 0, likeCount: Int = 0, exposures: [String: Int] = [:], likes: [String: Int] = [:],
        seeds: [String: Int] = [:]
    ) {
        self.swipeCount = swipeCount
        self.likeCount = likeCount
        self.exposures = exposures
        self.likes = likes
        self.seeds = seeds
    }

    enum CodingKeys: String, CodingKey {
        case swipeCount = "swipe_count"
        case likeCount = "like_count"
        case exposures, likes, seeds
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        swipeCount = try c.decode(Int.self, forKey: .swipeCount)
        likeCount = try c.decode(Int.self, forKey: .likeCount)
        exposures = try c.decode([String: Int].self, forKey: .exposures)
        likes = try c.decode([String: Int].self, forKey: .likes)
        seeds = try c.decodeIfPresent([String: Int].self, forKey: .seeds) ?? [:]
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(swipeCount, forKey: .swipeCount)
        try c.encode(likeCount, forKey: .likeCount)
        try c.encode(exposures, forKey: .exposures)
        try c.encode(likes, forKey: .likes)
        if !seeds.isEmpty { try c.encode(seeds, forKey: .seeds) }
    }

    /// Adds a swipe: S_d += 1 for each bucket; L_d += 1 too if liked.
    public func applying(_ swipe: TasteSwipe) -> TasteProfile {
        var p = self
        p.swipeCount += 1
        if swipe.liked { p.likeCount += 1 }
        for b in swipe.buckets {
            p.exposures[b, default: 0] += 1
            if swipe.liked { p.likes[b, default: 0] += 1 }
        }
        return p
    }

    /// Removes a previously applied swipe (one-level undo). Counts never go below the onboarding
    /// seed for the bucket (or zero), so undo never removes seeds.
    public func undoing(_ swipe: TasteSwipe) -> TasteProfile {
        var p = self
        p.swipeCount = max(0, p.swipeCount - 1)
        if swipe.liked { p.likeCount = max(0, p.likeCount - 1) }
        for b in swipe.buckets {
            Self.decrement(&p.exposures, b, floor: seeds[b] ?? 0)
            if swipe.liked { Self.decrement(&p.likes, b, floor: seeds[b] ?? 0) }
        }
        return p
    }

    /// Replaces any previous onboarding seed with the prior's: each seed bucket gets
    /// S_d += 2 and L_d += 2. Swipe counts are unchanged (seeds are not swipes).
    public func seeded(from prior: TastePrior) -> TasteProfile {
        var p = self
        for (b, n) in seeds {
            Self.subtract(&p.exposures, b, n)
            Self.subtract(&p.likes, b, n)
        }
        p.seeds = [:]
        for b in prior.seedBuckets {
            p.seeds[b] = TastePrior.seedCount
            p.exposures[b, default: 0] += TastePrior.seedCount
            p.likes[b, default: 0] += TastePrior.seedCount
        }
        return p
    }

    private static func decrement(_ dict: inout [String: Int], _ key: String, floor: Int) {
        let value = max(floor, (dict[key] ?? 0) - 1)
        dict[key] = value > 0 ? value : nil
    }

    private static func subtract(_ dict: inout [String: Int], _ key: String, _ n: Int) {
        let value = (dict[key] ?? 0) - n
        dict[key] = value > 0 ? value : nil
    }
}
