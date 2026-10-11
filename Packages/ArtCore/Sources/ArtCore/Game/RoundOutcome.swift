/// How a category answer matched.
public enum CategoryMatch: String, Codable, Sendable {
    case correct
    /// An accepted alternate category; counts as correct.
    case alternate
    case incorrect
}

/// The scored result of one round.
public struct RoundOutcome: Codable, Sendable, Equatable {
    /// nil for rounds without right/wrong (swipe).
    public var isCorrect: Bool?
    public var points: Int
    public var bidTier: BidTier?
    public var errorMilli: Int?
    public var categoryMatch: CategoryMatch?
    public var liked: Bool?

    public init(
        isCorrect: Bool?, points: Int, bidTier: BidTier? = nil, errorMilli: Int? = nil,
        categoryMatch: CategoryMatch? = nil, liked: Bool? = nil
    ) {
        self.isCorrect = isCorrect
        self.points = points
        self.bidTier = bidTier
        self.errorMilli = errorMilli
        self.categoryMatch = categoryMatch
        self.liked = liked
    }

    enum CodingKeys: String, CodingKey {
        case isCorrect = "is_correct"
        case points
        case bidTier = "bid_tier"
        case errorMilli = "error_milli"
        case categoryMatch = "category_match"
        case liked
    }

    /// An incorrect, zero-point outcome (used for mismatched or out-of-range answers).
    public static let invalid = RoundOutcome(isCorrect: false, points: 0)
}
