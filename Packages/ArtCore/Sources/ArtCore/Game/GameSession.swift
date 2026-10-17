/// A play session: generated rounds, the player's outcomes and the RNG needed to continue.
///
/// Fixed-length modes generate every round up front. "Which is pricier?" is endless: rounds are
/// generated in batches of 10 from the stored RNG, each new pair anchored on the previous
/// pricier work, and one wrong answer ends the run. Sessions are replayable from `seed`.
public struct GameSession: Codable, Sendable, Equatable {
    public let mode: GameMode
    public let seed: UInt64
    public private(set) var rounds: [Round]
    public private(set) var outcomes: [RoundOutcome]
    public private(set) var answers: [Answer]
    /// RNG state after the last generated round.
    public private(set) var rng: SplitMix64
    /// Artworks already shown, in order of appearance.
    public private(set) var used: [ArtworkID]
    /// Consecutive correct answers so far (swipes leave it unchanged).
    public private(set) var streak: Int
    public private(set) var isFinished: Bool
    /// Custom recipe passed to `make(mode:recipe:pool:seed:prior:)`, if any.
    public private(set) var customRecipe: [RoundSpec]?
    /// Onboarding prior used for weighted sampling (never for daily sessions).
    public private(set) var prior: TastePrior?

    /// Rounds generated per endless batch.
    public static let batchSize = 10

    enum CodingKeys: String, CodingKey {
        case mode, seed, rounds, outcomes, answers, rng, used, streak
        case isFinished = "is_finished"
        case customRecipe = "custom_recipe"
        case prior
    }

    /// The fixed recipe for a mode, or nil for endless modes.
    public static func recipe(for mode: GameMode) -> [RoundSpec]? {
        func ramp(_ kind: RoundKind) -> [RoundSpec] {
            Array(repeating: RoundSpec(kind, .easy), count: 3) + Array(repeating: RoundSpec(kind, .medium), count: 4)
                + Array(repeating: RoundSpec(kind, .hard), count: 3)
        }
        switch mode {
        case .pickPrice: return ramp(.pickPrice)
        case .category: return ramp(.category)
        case .bid: return Array(repeating: RoundSpec(.bid, .medium), count: 10)
        case .swipe: return Array(repeating: RoundSpec(.swipe, .medium), count: 20)
        case .daily: return DailyChallenge.recipe
        case .higherLower: return nil
        }
    }

    /// Difficulty of endless round `index`: <5 easy, <15 medium, else hard.
    public static func higherLowerDifficulty(roundIndex: Int) -> Difficulty {
        roundIndex < 5 ? .easy : (roundIndex < 15 ? .medium : .hard)
    }

    /// Creates a session with `SplitMix64(seed: seed)`. Fixed recipes generate all rounds in order
    /// with a shared `used` set (throws if any round fails); endless modes generate the first batch.
    public static func make(mode: GameMode, pool: GamePool, seed: UInt64) throws -> GameSession {
        try make(mode: mode, recipe: nil, pool: pool, seed: seed, prior: nil)
    }

    /// Creates a session with a custom recipe and/or an onboarding prior.
    ///
    /// - `recipe`: for fixed modes, replaces the default recipe (nil = default). For
    ///   `higher_lower`, round `i` uses `recipe[min(i, count − 1)].difficulty` instead of the ramp
    ///   (the kinds in the recipe are ignored). Ignored for `daily`.
    /// - `prior`: weighted artwork sampling and same-department pair preference (see
    ///   `RoundGenerator`). Ignored for `daily`, which is identical for every player.
    public static func make(
        mode: GameMode, recipe: [RoundSpec]?, pool: GamePool, seed: UInt64, prior: TastePrior? = nil
    ) throws -> GameSession {
        let isDaily = mode == .daily
        let custom = isDaily || recipe?.isEmpty == true ? nil : recipe
        var session = GameSession(
            mode: mode, seed: seed, rounds: [], outcomes: [], answers: [], rng: SplitMix64(seed: seed),
            used: [], streak: 0, isFinished: false)
        session.customRecipe = custom
        session.prior = isDaily ? nil : prior
        if let fixed = Self.recipe(for: mode) {
            var usedSet = Set<ArtworkID>()
            for spec in custom ?? fixed {
                let round = try RoundGenerator.makeRound(
                    spec: spec, pool: pool, used: usedSet, prior: session.prior, rng: &session.rng)
                session.append(round, usedSet: &usedSet)
            }
        } else {
            try session.appendBatch(pool: pool)
            if session.rounds.isEmpty { throw GenerationError.poolExhausted(.higherLower) }
        }
        return session
    }

    /// Index of the current round (= number of answers given).
    public var index: Int { outcomes.count }

    /// The round awaiting an answer, if any.
    public var currentRound: Round? {
        isFinished || index >= rounds.count ? nil : rounds[index]
    }

    /// Total points so far.
    public var totalPoints: Int { outcomes.reduce(0) { $0 + $1.points } }

    /// True for modes that generate rounds in batches.
    public var isEndless: Bool { Self.recipe(for: mode) == nil }

    /// True when an endless session has at most one unanswered round left and should call `appendBatch`.
    public var needsMoreRounds: Bool {
        isEndless && !isFinished && rounds.count - outcomes.count <= 1
    }

    /// Scores `answer` against the current round and advances. Returns nil if the session is finished.
    /// The streak bonus is not applied in daily sessions (their maximum is 100 per round).
    @discardableResult
    public mutating func submit(_ answer: Answer) -> RoundOutcome? {
        guard let round = currentRound else { return nil }
        let outcome = Scorer.score(round, answer, streak: mode == .daily ? 0 : streak)
        outcomes.append(outcome)
        answers.append(answer)
        switch outcome.isCorrect {
        case true?: streak += 1
        case false?: streak = 0
        case nil: break
        }
        if mode == .higherLower && outcome.isCorrect == false {
            isFinished = true
        } else if !isEndless && outcomes.count == rounds.count {
            isFinished = true
        }
        return outcome
    }

    /// Generates up to `batchSize` more endless rounds. Each pair is anchored on the previous
    /// round's challenger (its bottom work), so the run walks through the pool like higher-or-lower
    /// instead of climbing to the dearest work and staying there (anchoring on the winner made every
    /// later round "is anything pricier than a $260M van Gogh?"). Generation stops at the first
    /// failure; if nothing could be added and no round is pending, the session finishes (pool exhausted).
    public mutating func appendBatch(pool: GamePool) throws {
        guard isEndless, !isFinished else { return }
        var usedSet = Set(used)
        var added = 0
        for _ in 0..<Self.batchSize {
            let difficulty =
                customRecipe.map { $0[min(rounds.count, $0.count - 1)].difficulty }
                ?? Self.higherLowerDifficulty(roundIndex: rounds.count)
            var anchor: ArtworkID?
            if case .higherLower(let last)? = rounds.last { anchor = last.bottom }
            var trialRng = rng
            guard
                let round = try? RoundGenerator.makeRound(
                    spec: RoundSpec(.higherLower, difficulty), pool: pool, used: usedSet, anchor: anchor,
                    prior: prior, rng: &trialRng)
            else { break }
            rng = trialRng
            append(round, usedSet: &usedSet)
            added += 1
        }
        if added == 0 && currentRound == nil {
            isFinished = true
        }
    }

    private mutating func append(_ round: Round, usedSet: inout Set<ArtworkID>) {
        rounds.append(round)
        for id in round.artworkIDs where !usedSet.contains(id) {
            usedSet.insert(id)
            used.append(id)
        }
    }

    private init(
        mode: GameMode, seed: UInt64, rounds: [Round], outcomes: [RoundOutcome], answers: [Answer],
        rng: SplitMix64, used: [ArtworkID], streak: Int, isFinished: Bool
    ) {
        self.mode = mode
        self.seed = seed
        self.rounds = rounds
        self.outcomes = outcomes
        self.answers = answers
        self.rng = rng
        self.used = used
        self.streak = streak
        self.isFinished = isFinished
    }
}
