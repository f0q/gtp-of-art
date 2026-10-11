import ArtCore

/// Why a standalone session could not be created.
public enum SessionFactoryError: Error, Sendable, Equatable {
    /// The daily challenge is created by `DailyService`, not here.
    case dailyNotStandalone
    /// No longer thrown (custom difficulty is supported since ArtCore round 2); kept for source
    /// compatibility.
    case customDifficultyUnsupported(GameMode)
    /// ArtCore could not generate the rounds.
    case generation(GenerationError)
    /// Any other error (not expected from ArtCore today).
    case unexpected(String)
}

/// Creates the five standalone sessions (pick the price, which is pricier, category, bid, swipe).
///
/// Default rounds follow spec §15: pick the price and category ramp 3 easy / 4 medium / 3 hard,
/// bid is 10 medium, swipe 20, and which-is-pricier is endless — generated in batches of 10 from
/// the stored RNG; call `extendIfNeeded` after each answer. A chosen difficulty and an onboarding
/// prior go through ArtCore's `GameSession.make(mode:recipe:pool:seed:prior:)`.
public enum SessionFactory {
    /// A fresh random session seed (the seed is random; everything after it is deterministic, so
    /// a session can be replayed from its seed for bug reports).
    public static func randomSeed() -> UInt64 {
        var generator = SystemRandomNumberGenerator()
        return generator.next()
    }

    /// The recipe used for `mode` at a chosen difficulty (nil difficulty → nil = spec default).
    ///
    /// - pick the price, category, bid: 10 rounds of that difficulty (bid ignores difficulty).
    /// - swipe: 20 rounds (difficulty has no effect on swipes).
    /// - which is pricier: a ramp that *starts* at the difficulty — easy = the default ramp
    ///   (5 easy, 10 medium, then hard), medium = 10 medium then hard, hard = hard throughout.
    ///   ArtCore uses `recipe[min(i, count − 1)]` for round `i`, so the last entry repeats.
    public static func recipe(for mode: GameMode, difficulty: Difficulty?) -> [RoundSpec]? {
        guard let difficulty else { return nil }
        switch mode {
        case .pickPrice, .category, .bid:
            let kind: RoundKind = mode == .pickPrice ? .pickPrice : (mode == .category ? .category : .bid)
            return Array(repeating: RoundSpec(kind, difficulty), count: 10)
        case .swipe:
            return Array(repeating: RoundSpec(.swipe, difficulty), count: 20)
        case .higherLower:
            let easy = Array(repeating: RoundSpec(.higherLower, .easy), count: 5)
            let medium = Array(repeating: RoundSpec(.higherLower, .medium), count: 10)
            let hard = [RoundSpec(.higherLower, .hard)]
            switch difficulty {
            case .easy: return easy + medium + hard
            case .medium: return medium + hard
            case .hard: return hard
            }
        case .daily:
            return nil
        }
    }

    /// Builds a session.
    /// - Parameters:
    ///   - difficulty: nil plays the spec recipe; a value plays `recipe(for:difficulty:)`.
    ///   - seed: session seed; the same seed, dataset, difficulty and prior give the same rounds.
    ///   - prior: onboarding prior (weighted artwork picks, same-department pairs first); nil = uniform.
    public static func make(
        mode: GameMode, difficulty: Difficulty? = nil, dataset: any DatasetProviding, seed: UInt64,
        prior: TastePrior? = nil
    ) throws(SessionFactoryError) -> GameSession {
        guard mode != .daily else { throw .dailyNotStandalone }
        do {
            return try GameSession.make(
                mode: mode, recipe: recipe(for: mode, difficulty: difficulty), pool: dataset.pool, seed: seed,
                prior: prior)
        } catch let error as GenerationError {
            throw .generation(error)
        } catch {
            throw .unexpected(String(describing: error))
        }
    }

    /// For endless sessions: when at most one unanswered round remains, generates the next batch
    /// of 10. Returns the number of rounds added (0 when nothing was needed or the pool ran dry,
    /// in which case the session finishes once the pending rounds are answered).
    @discardableResult
    public static func extendIfNeeded(_ session: inout GameSession, dataset: any DatasetProviding) -> Int {
        guard session.needsMoreRounds else { return 0 }
        let before = session.rounds.count
        try? session.appendBatch(pool: dataset.pool)
        return session.rounds.count - before
    }
}
