/// The daily challenge: five seeded rounds identical for every player on the same day,
/// dataset and rules version.
public struct DailyChallenge: Codable, Sendable, Equatable {
    public var day: DayKey
    public var seed: UInt64
    public var rounds: [Round]

    /// Bump when daily generation rules change (it is part of the seed).
    /// 2: category distractors may come from any active category (spec §11).
    public static let currentRulesVersion = 2

    /// `[pickPrice.easy, higherLower.medium, category.medium, bid.medium, pickPrice.hard]`.
    public static let recipe: [RoundSpec] = [
        RoundSpec(.pickPrice, .easy),
        RoundSpec(.higherLower, .medium),
        RoundSpec(.category, .medium),
        RoundSpec(.bid, .medium),
        RoundSpec(.pickPrice, .hard),
    ]

    /// Generates the challenge: `seed = DailySeed.seed(...)`, one `SplitMix64(seed)` stream,
    /// rounds in recipe order with a shared `used` set so no artwork repeats.
    public static func make(
        dayKey: DayKey, pool: GamePool, datasetVersion: String, dailyRulesVersion: Int = currentRulesVersion
    ) throws -> DailyChallenge {
        let seed = DailySeed.seed(day: dayKey, datasetVersion: datasetVersion, dailyRulesVersion: dailyRulesVersion)
        let session = try GameSession.make(mode: .daily, pool: pool, seed: seed)
        return DailyChallenge(day: dayKey, seed: seed, rounds: session.rounds)
    }

    /// A playable session for the day (same rounds as `make`).
    public static func session(
        dayKey: DayKey, pool: GamePool, datasetVersion: String, dailyRulesVersion: Int = currentRulesVersion
    ) throws -> GameSession {
        let seed = DailySeed.seed(day: dayKey, datasetVersion: datasetVersion, dailyRulesVersion: dailyRulesVersion)
        return try GameSession.make(mode: .daily, pool: pool, seed: seed)
    }
}
