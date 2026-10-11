/// One answered round, appended to `rounds.jsonl` (the source of truth for stats).
public struct RoundRecord: Codable, Sendable, Equatable {
    public var mode: GameMode
    public var sessionSeed: UInt64
    public var roundIndex: Int
    public var round: Round
    public var answer: Answer
    public var outcome: RoundOutcome
    /// Daily challenge day, if any.
    public var day: DayKey?
    /// Unix time in seconds, supplied by the caller (ArtCore has no clock).
    public var playedAt: Int64

    public init(
        mode: GameMode, sessionSeed: UInt64, roundIndex: Int, round: Round, answer: Answer,
        outcome: RoundOutcome, day: DayKey?, playedAt: Int64
    ) {
        self.mode = mode
        self.sessionSeed = sessionSeed
        self.roundIndex = roundIndex
        self.round = round
        self.answer = answer
        self.outcome = outcome
        self.day = day
        self.playedAt = playedAt
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case sessionSeed = "session_seed"
        case roundIndex = "round_index"
        case round, answer, outcome, day
        case playedAt = "played_at"
    }
}
