import ArtCore

/// Result of generating many independent rounds of one kind at one difficulty.
public struct RoundProbeResult: Sendable, Equatable {
    public var kind: RoundKind
    public var difficulty: Difficulty
    /// Independent rounds attempted (fresh RNG, empty `used` set each time).
    public var attempts: Int
    public var successes: Int
    /// Failure counts keyed by `GenerationError.code`.
    public var failures: [String: Int]
    /// Rounds generated back to back from one RNG with a shared `used` set before the first
    /// failure (capped at `capacityCap`): how long a no-repeat run can get.
    public var capacity: Int
    /// Which-is-pricier rounds whose constraints had to be relaxed (`relaxation > 0`).
    public var relaxed: Int

    /// Upper bound of `capacity` measurements.
    public static let capacityCap = 100
}

/// Result of building complete standalone sessions for one mode.
public struct SessionProbeResult: Sendable, Equatable {
    public var mode: GameMode
    public var attempts: Int
    public var successes: Int
    /// Failure counts keyed by `GenerationError.code`.
    public var failures: [String: Int]
    /// Rounds in the first successful session (first batch for endless modes).
    public var roundsPerSession: Int
    /// Endless modes only: shortest run a perfect player reaches before the pool runs dry
    /// (capped at `endlessCap`); nil for fixed recipes.
    public var shortestPerfectRun: Int?

    /// Upper bound of perfect-run measurements.
    public static let endlessCap = 200
}

/// Quiz readiness of one taxonomy category.
public struct CategoryCoverage: Sendable, Equatable {
    public var id: CategoryID
    public var axis: CategoryAxis
    public var active: Bool
    /// Playable works whose primary category this is.
    public var primaryCount: Int
    public var minQuizItems: Int
    public var quizEligible: Bool
}

/// Drives the ArtCore generators against a pool to measure how much content each mode really has.
/// Seeds are derived with FNV-1a from a fixed label, so results are reproducible.
public enum GeneratorProbe {
    /// The seed for probe `index` of `label`.
    public static func seed(_ label: String, _ index: Int) -> UInt64 {
        fnv1a64("artdata|probe|\(label)|\(index)")
    }

    /// Generates `attempts` independent rounds plus one capacity run.
    public static func probeRounds(kind: RoundKind, difficulty: Difficulty, pool: GamePool, attempts: Int)
        -> RoundProbeResult
    {
        var result = RoundProbeResult(
            kind: kind, difficulty: difficulty, attempts: attempts, successes: 0, failures: [:], capacity: 0,
            relaxed: 0)
        let spec = RoundSpec(kind, difficulty)
        for i in 0..<attempts {
            var rng = SplitMix64(seed: seed("\(kind.rawValue)|\(difficulty.rawValue)", i))
            do {
                let round = try RoundGenerator.makeRound(spec: spec, pool: pool, used: [], rng: &rng)
                result.successes += 1
                if case .higherLower(let pair) = round, pair.relaxation > 0 { result.relaxed += 1 }
            } catch {
                result.failures[code(of: error), default: 0] += 1
            }
        }
        var rng = SplitMix64(seed: seed("capacity|\(kind.rawValue)|\(difficulty.rawValue)", 0))
        var used = Set<ArtworkID>()
        while result.capacity < RoundProbeResult.capacityCap,
            let round = try? RoundGenerator.makeRound(spec: spec, pool: pool, used: used, rng: &rng)
        {
            used.formUnion(round.artworkIDs)
            result.capacity += 1
        }
        return result
    }

    /// Builds `attempts` sessions of `mode` with `GameSession.make` (the daily mode is covered by
    /// `DailyValidator` instead).
    public static func probeSessions(mode: GameMode, pool: GamePool, attempts: Int) -> SessionProbeResult {
        var result = SessionProbeResult(
            mode: mode, attempts: attempts, successes: 0, failures: [:], roundsPerSession: 0, shortestPerfectRun: nil)
        for i in 0..<attempts {
            do {
                let session = try GameSession.make(mode: mode, pool: pool, seed: seed("session|\(mode.rawValue)", i))
                if result.successes == 0 { result.roundsPerSession = session.rounds.count }
                result.successes += 1
                if session.isEndless {
                    let run = perfectRunLength(session, pool: pool)
                    result.shortestPerfectRun = min(result.shortestPerfectRun ?? run, run)
                }
            } catch {
                result.failures[code(of: error), default: 0] += 1
            }
        }
        return result
    }

    /// Plays an endless session perfectly (always the pricier side), extending it in batches,
    /// until the pool runs dry or `endlessCap` rounds; returns the number of rounds answered.
    static func perfectRunLength(_ start: GameSession, pool: GamePool) -> Int {
        var session = start
        while !session.isFinished, session.outcomes.count < SessionProbeResult.endlessCap {
            if session.needsMoreRounds { try? session.appendBatch(pool: pool) }
            guard case .higherLower(let pair)? = session.currentRound else { break }
            session.submit(.higherLower(side: pair.pricierSide))
        }
        return session.outcomes.count
    }

    /// Quiz readiness of every category in the pool's taxonomy.
    public static func categoryCoverage(pool: GamePool) -> [CategoryCoverage] {
        var counts: [CategoryID: Int] = [:]
        for a in pool.artworks { counts[a.category, default: 0] += 1 }
        return pool.categories.map { c in
            CategoryCoverage(
                id: c.id, axis: c.axis, active: c.active, primaryCount: counts[c.id, default: 0],
                minQuizItems: c.minQuizItems, quizEligible: pool.quizCategoryIDs.contains(c.id))
        }
    }

    static func code(of error: any Error) -> String {
        (error as? GenerationError)?.code ?? String(describing: error)
    }
}
