/// Bid accuracy tier.
public enum BidTier: String, Codable, Sendable, CaseIterable {
    case bullseye
    case expertEye = "expert_eye"
    case goodInstinct = "good_instinct"
    case inTheRoom = "in_the_room"
    case offTheWall = "off_the_wall"

    /// Points for the tier.
    public var points: Int {
        switch self {
        case .bullseye: 100
        case .expertEye: 70
        case .goodInstinct: 40
        case .inTheRoom: 15
        case .offTheWall: 0
        }
    }

    /// Largest error (milli-decades) that still earns the tier; nil for `offTheWall`.
    public var maxErrorMilli: Int? {
        switch self {
        case .bullseye: 97
        case .expertEye: 301
        case .goodInstinct: 699
        case .inTheRoom: 1000
        case .offTheWall: nil
        }
    }
}

/// Whether the bid was below, above or exactly at the actual price.
public enum BidDirection: String, Codable, Sendable {
    case under, over, exact
}

/// The scored bid.
public struct BidResult: Sendable, Equatable, Codable {
    public var position: Int
    public var guessMilli: Int
    public var actualMilli: Int
    public var errorMilli: Int
    public var tier: BidTier
    public var points: Int
    public var direction: BidDirection

    public init(
        position: Int, guessMilli: Int, actualMilli: Int, errorMilli: Int, tier: BidTier, points: Int,
        direction: BidDirection
    ) {
        self.position = position
        self.guessMilli = guessMilli
        self.actualMilli = actualMilli
        self.errorMilli = errorMilli
        self.tier = tier
        self.points = points
        self.direction = direction
    }

    /// Display-only ratio between bid and actual: 10^(errorMilli/1000) ("3.1× under").
    public var factor: Double { DisplayMath.pow10(Double(errorMilli) / 1000) }

    enum CodingKeys: String, CodingKey {
        case position
        case guessMilli = "guess_milli"
        case actualMilli = "actual_milli"
        case errorMilli = "error_milli"
        case tier, points, direction
    }
}

/// Bid / estimate scoring on a log scale in integer milli-decades.
public enum BidScorer {
    public static let positionRange = 0...700
    /// Slider position 0 → 10^2.000 = $100; 700 → 10^9.000 = $1B; 0.01 decade per step.
    public static let baseMilli = 2000
    public static let milliPerStep = 10

    /// `2000 + 10·p` with `p` clamped to 0…700.
    public static func guessMilli(position: Int) -> Int {
        baseMilli + milliPerStep * min(max(position, positionRange.lowerBound), positionRange.upperBound)
    }

    /// The tier for an absolute error: ≤97 bullseye · ≤301 expert eye · ≤699 good instinct ·
    /// ≤1000 in the room · else off the wall.
    public static func tier(errorMilli: Int) -> BidTier {
        switch errorMilli {
        case ...97: .bullseye
        case ...301: .expertEye
        case ...699: .goodInstinct
        case ...1000: .inTheRoom
        default: .offTheWall
        }
    }

    /// Scores a slider position against the actual price's `log10_usd_nominal_milli`.
    public static func score(position: Int, actualMilli: Int) -> BidResult {
        let p = min(max(position, positionRange.lowerBound), positionRange.upperBound)
        let guess = guessMilli(position: p)
        let error = abs(guess - actualMilli)
        let t = tier(errorMilli: error)
        let direction: BidDirection = guess < actualMilli ? .under : (guess > actualMilli ? .over : .exact)
        return BidResult(
            position: p, guessMilli: guess, actualMilli: actualMilli, errorMilli: error, tier: t,
            points: t.points, direction: direction)
    }

    /// Nearest slider position for a milli value (ties round up), clamped to 0…700.
    public static func position(forMilli milli: Int) -> Int {
        let offset = milli - baseMilli
        let p = offset >= 0 ? (offset + milliPerStep / 2) / milliPerStep : -((-offset) / milliPerStep)
        return min(max(p, positionRange.lowerBound), positionRange.upperBound)
    }

    /// Display-only dollar value for a slider position, rounded to 2 significant figures.
    public static func displayUSD(position: Int) -> Int64 {
        let value = DisplayMath.pow10(Double(guessMilli(position: position)) / 1000)
        return SigFig.round2(Int64(value.rounded()))
    }
}
