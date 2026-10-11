/// A playable mode on the hub. Encodes as snake_case; usable as a JSON object key.
public enum GameMode: String, Codable, CodingKeyRepresentable, Sendable, CaseIterable {
    case pickPrice = "pick_price"
    case higherLower = "higher_lower"
    case category
    case bid
    case swipe
    case daily
}

/// The kind of a single round. Daily sessions mix kinds.
public enum RoundKind: String, Codable, CodingKeyRepresentable, Sendable, CaseIterable {
    case pickPrice = "pick_price"
    case higherLower = "higher_lower"
    case category
    case bid
    case swipe
}

/// Difficulty level of a round.
public enum Difficulty: String, Codable, Sendable, CaseIterable {
    case easy, medium, hard
}

/// What to generate for one round.
public struct RoundSpec: Codable, Sendable, Hashable {
    public var kind: RoundKind
    public var difficulty: Difficulty
    public init(_ kind: RoundKind, _ difficulty: Difficulty) {
        self.kind = kind
        self.difficulty = difficulty
    }
}

/// Why a round (or session) could not be generated.
public enum GenerationError: Error, Sendable, Equatable {
    /// The truth price is outside the playable band.
    case priceOutOfBand(Int64)
    /// No option set satisfied the distractor constraints.
    case noValidPriceOptions(Int64)
    /// Not enough eligible artworks left for this round kind.
    case poolExhausted(RoundKind)
    /// The artwork has no quiz-eligible category.
    case noQuizCategory(ArtworkID)
    /// Fewer than three distractor categories were available.
    case notEnoughDistractors(ArtworkID)
    /// The anchor artwork is missing or unpriced.
    case invalidAnchor(ArtworkID)
}

extension GenerationError: CustomStringConvertible {
    /// `code(detail)`, e.g. `pool_exhausted(higher_lower)`.
    public var description: String {
        switch self {
        case .priceOutOfBand(let usd), .noValidPriceOptions(let usd): "\(code)(\(usd))"
        case .poolExhausted(let kind): "\(code)(\(kind.rawValue))"
        case .noQuizCategory(let id), .notEnoughDistractors(let id), .invalidAnchor(let id): "\(code)(\(id))"
        }
    }

    /// Platform-neutral error code used in fixtures.
    public var code: String {
        switch self {
        case .priceOutOfBand: "price_out_of_band"
        case .noValidPriceOptions: "no_valid_price_options"
        case .poolExhausted: "pool_exhausted"
        case .noQuizCategory: "no_quiz_category"
        case .notEnoughDistractors: "not_enough_distractors"
        case .invalidAnchor: "invalid_anchor"
        }
    }
}
