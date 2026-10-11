/// Kind of price a record documents.
public enum PriceType: String, Codable, Sendable, CaseIterable {
    case auctionPremium = "auction_premium"
    case auctionHammer = "auction_hammer"
    case privateSale = "private_sale"
    case askPrice = "ask_price"
    case selfReported = "self_reported"
    case estimateLow = "estimate_low"
    case estimateHigh = "estimate_high"

    /// Estimates are never game prices.
    public var isEstimate: Bool { self == .estimateLow || self == .estimateHigh }
}

/// Whether the priced object is the object pictured.
public enum PriceScope: String, Codable, Sendable, CaseIterable {
    case thisObject = "this_object"
    case sameEditionOtherImpression = "same_edition_other_impression"
    /// Another version of the composition. Never game-eligible.
    case otherVersion = "other_version"
}

/// Curator confidence in a price record.
public enum Confidence: String, Codable, Sendable, CaseIterable {
    case high, medium, low
}

/// One documented price for an artwork. Monetary values are integers; logs are precomputed by
/// the dataset pipeline and are the only values game logic uses for comparisons and scoring.
public struct PriceRecord: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    /// Original amount in minor units of `currency` (whole units for zero-decimal currencies).
    public var amountMinor: Int64
    /// ISO 4217 code of the original amount.
    public var currency: String
    public var type: PriceType
    /// For auctions: whether the amount includes buyer's premium (nil when unknown/not applicable).
    public var premiumIncluded: Bool?
    /// Reported/rounded/FX-converted figure.
    public var approximate: Bool
    /// The true price is at least this amount ("$250M+").
    public var lowerBound: Bool
    /// Sale date: `"YYYY-MM-DD"`, `"YYYY-MM"` or `"YYYY"`.
    public var date: String
    public var venue: String?
    /// Whole US dollars at sale-date exchange rates.
    public var usdNominal: Int64
    /// Whole US dollars adjusted to `adjustRefYear` (CPI-U).
    public var usdAdjusted: Int64
    public var adjustRefYear: Int
    /// `round(1000 · log10(usdNominal))`.
    public var log10UsdNominalMilli: Int
    /// `round(1000 · log10(usdAdjusted))`.
    public var log10UsdAdjustedMilli: Int
    public var sourceURLs: [String]
    public var confidence: Confidence
    public var gameEligible: Bool
    public var priceScope: PriceScope

    public init(
        id: String, amountMinor: Int64, currency: String, type: PriceType, premiumIncluded: Bool?,
        approximate: Bool, lowerBound: Bool, date: String, venue: String?, usdNominal: Int64,
        usdAdjusted: Int64, adjustRefYear: Int, log10UsdNominalMilli: Int, log10UsdAdjustedMilli: Int,
        sourceURLs: [String], confidence: Confidence, gameEligible: Bool, priceScope: PriceScope
    ) {
        self.id = id
        self.amountMinor = amountMinor
        self.currency = currency
        self.type = type
        self.premiumIncluded = premiumIncluded
        self.approximate = approximate
        self.lowerBound = lowerBound
        self.date = date
        self.venue = venue
        self.usdNominal = usdNominal
        self.usdAdjusted = usdAdjusted
        self.adjustRefYear = adjustRefYear
        self.log10UsdNominalMilli = log10UsdNominalMilli
        self.log10UsdAdjustedMilli = log10UsdAdjustedMilli
        self.sourceURLs = sourceURLs
        self.confidence = confidence
        self.gameEligible = gameEligible
        self.priceScope = priceScope
    }

    enum CodingKeys: String, CodingKey {
        case id
        case amountMinor = "amount_minor"
        case currency, type
        case premiumIncluded = "premium_included"
        case approximate
        case lowerBound = "lower_bound"
        case date, venue
        case usdNominal = "usd_nominal"
        case usdAdjusted = "usd_adjusted"
        case adjustRefYear = "adjust_ref_year"
        case log10UsdNominalMilli = "log10_usd_nominal_milli"
        case log10UsdAdjustedMilli = "log10_usd_adjusted_milli"
        case sourceURLs = "source_urls"
        case confidence
        case gameEligible = "game_eligible"
        case priceScope = "price_scope"
    }

    /// The four-digit sale year parsed from `date`, if present.
    public var saleYear: Int? {
        let digits = Array(date.utf8.prefix(4))
        guard digits.count == 4 else { return nil }
        var value = 0
        for b in digits {
            guard b >= 0x30, b <= 0x39 else { return nil }
            value = value * 10 + Int(b - 0x30)
        }
        return value
    }

    /// True if this record may be used as a game price: flagged eligible, not an estimate,
    /// not another version, and not low confidence.
    public var isUsableForGame: Bool {
        gameEligible && !type.isEstimate && priceScope != .otherVersion && confidence != .low
    }
}
