/// "Pick the price" payload.
public struct PickPriceRound: Codable, Sendable, Equatable {
    public var artwork: ArtworkID
    public var priceID: String
    /// Four ascending options in whole USD (nominal), all rounded to 2 significant figures.
    public var options: [Int64]
    public var correctIndex: Int
    public var difficulty: Difficulty

    public init(artwork: ArtworkID, priceID: String, options: [Int64], correctIndex: Int, difficulty: Difficulty) {
        self.artwork = artwork
        self.priceID = priceID
        self.options = options
        self.correctIndex = correctIndex
        self.difficulty = difficulty
    }

    enum CodingKeys: String, CodingKey {
        case artwork
        case priceID = "price_id"
        case options
        case correctIndex = "correct_index"
        case difficulty
    }
}

/// "Which is pricier?" payload (stacked vertically). Compares adjusted USD.
public struct HigherLowerRound: Codable, Sendable, Equatable {
    public var top: ArtworkID
    public var bottom: ArtworkID
    public var topMilli: Int
    public var bottomMilli: Int
    public var pricierSide: PricierSide
    /// 0 = requested constraints; higher values = relaxation passes used (see `PairSelector`).
    public var relaxation: Int
    public var difficulty: Difficulty

    public init(
        top: ArtworkID, bottom: ArtworkID, topMilli: Int, bottomMilli: Int, pricierSide: PricierSide, relaxation: Int,
        difficulty: Difficulty
    ) {
        self.top = top
        self.bottom = bottom
        self.topMilli = topMilli
        self.bottomMilli = bottomMilli
        self.pricierSide = pricierSide
        self.relaxation = relaxation
        self.difficulty = difficulty
    }

    /// The pricier artwork.
    public var pricier: ArtworkID { pricierSide == .top ? top : bottom }

    enum CodingKeys: String, CodingKey {
        case top, bottom
        case topMilli = "top_milli"
        case bottomMilli = "bottom_milli"
        case pricierSide = "pricier_side"
        case relaxation, difficulty
    }
}

/// Category quiz payload.
public struct CategoryRound: Codable, Sendable, Equatable {
    public var artwork: ArtworkID
    /// Four category options.
    public var options: [CategoryID]
    public var correctIndex: Int
    /// Other categories that also count as correct (flagged "alternate").
    public var accepted: [CategoryID]
    public var difficulty: Difficulty

    public init(artwork: ArtworkID, options: [CategoryID], correctIndex: Int, accepted: [CategoryID], difficulty: Difficulty) {
        self.artwork = artwork
        self.options = options
        self.correctIndex = correctIndex
        self.accepted = accepted
        self.difficulty = difficulty
    }

    enum CodingKeys: String, CodingKey {
        case artwork, options
        case correctIndex = "correct_index"
        case accepted, difficulty
    }
}

/// Bid / estimate payload. Uses nominal USD.
public struct BidRound: Codable, Sendable, Equatable {
    public var artwork: ArtworkID
    public var priceID: String
    public var actualMilli: Int
    public var actualUSD: Int64

    public init(artwork: ArtworkID, priceID: String, actualMilli: Int, actualUSD: Int64) {
        self.artwork = artwork
        self.priceID = priceID
        self.actualMilli = actualMilli
        self.actualUSD = actualUSD
    }

    enum CodingKeys: String, CodingKey {
        case artwork
        case priceID = "price_id"
        case actualMilli = "actual_milli"
        case actualUSD = "actual_usd"
    }
}

/// Swipe payload.
public struct SwipeRound: Codable, Sendable, Equatable {
    public var artwork: ArtworkID
    public init(artwork: ArtworkID) { self.artwork = artwork }
}

/// One generated round. JSON: `{"kind": "<round kind>", "payload": {...}}`.
public enum Round: Codable, Sendable, Equatable {
    case pickPrice(PickPriceRound)
    case higherLower(HigherLowerRound)
    case category(CategoryRound)
    case bid(BidRound)
    case swipe(SwipeRound)

    public var kind: RoundKind {
        switch self {
        case .pickPrice: .pickPrice
        case .higherLower: .higherLower
        case .category: .category
        case .bid: .bid
        case .swipe: .swipe
        }
    }

    /// Artworks shown in this round (top first for pairs).
    public var artworkIDs: [ArtworkID] {
        switch self {
        case .pickPrice(let r): [r.artwork]
        case .higherLower(let r): [r.top, r.bottom]
        case .category(let r): [r.artwork]
        case .bid(let r): [r.artwork]
        case .swipe(let r): [r.artwork]
        }
    }

    enum CodingKeys: String, CodingKey { case kind, payload }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(RoundKind.self, forKey: .kind) {
        case .pickPrice: self = .pickPrice(try c.decode(PickPriceRound.self, forKey: .payload))
        case .higherLower: self = .higherLower(try c.decode(HigherLowerRound.self, forKey: .payload))
        case .category: self = .category(try c.decode(CategoryRound.self, forKey: .payload))
        case .bid: self = .bid(try c.decode(BidRound.self, forKey: .payload))
        case .swipe: self = .swipe(try c.decode(SwipeRound.self, forKey: .payload))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        switch self {
        case .pickPrice(let r): try c.encode(r, forKey: .payload)
        case .higherLower(let r): try c.encode(r, forKey: .payload)
        case .category(let r): try c.encode(r, forKey: .payload)
        case .bid(let r): try c.encode(r, forKey: .payload)
        case .swipe(let r): try c.encode(r, forKey: .payload)
        }
    }
}
