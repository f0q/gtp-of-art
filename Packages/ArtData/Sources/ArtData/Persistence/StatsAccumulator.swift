import ArtCore

/// Folds round records into `ModeStats` and `DailyState`, exactly as a live session would.
///
/// Records are grouped into runs by `(mode, session_seed, day)`; a record with `round_index == 0`
/// starts a new run of the same key (a replay). A run completes when it reaches its recipe length
/// (fixed modes, daily) or on its first wrong answer (endless which-is-pricier). On completion the
/// mode gets `recordingSession(points:longestStreak:)` and a daily run calls
/// `DailyState.completing(day, score:)` (replays of a completed day change nothing). Unfinished
/// runs count towards round stats only.
public struct StatsAccumulator: Sendable, Equatable {
    public private(set) var stats: [GameMode: ModeStats]
    public private(set) var daily: DailyState
    private var openRuns: [RunKey: Run] = [:]

    struct RunKey: Hashable, Sendable {
        var mode: GameMode
        var seed: UInt64
        var day: DayKey?
    }

    struct Run: Equatable, Sendable {
        var count = 0
        var points = 0
        var streak = 0
        var longest = 0
    }

    public init(stats: [GameMode: ModeStats] = [:], daily: DailyState = DailyState()) {
        self.stats = stats
        self.daily = daily
    }

    /// Adds one answered round.
    public mutating func add(_ record: RoundRecord) {
        stats[record.mode, default: ModeStats()] = stats[record.mode, default: ModeStats()].recording(record.outcome)
        let key = RunKey(mode: record.mode, seed: record.sessionSeed, day: record.day)
        var run = record.roundIndex == 0 ? Run() : (openRuns[key] ?? Run())
        run.count += 1
        run.points += record.outcome.points
        switch record.outcome.isCorrect {
        case true?:
            run.streak += 1
            run.longest = max(run.longest, run.streak)
        case false?: run.streak = 0
        case nil: break
        }
        if Self.completes(run, mode: record.mode, outcome: record.outcome) {
            openRuns[key] = nil
            stats[record.mode] = stats[record.mode]!.recordingSession(points: run.points, longestStreak: run.longest)
            if record.mode == .daily, let day = record.day {
                daily = daily.completing(day, score: run.points)
            }
        } else {
            openRuns[key] = run
        }
    }

    static func completes(_ run: Run, mode: GameMode, outcome: RoundOutcome) -> Bool {
        if let recipe = GameSession.recipe(for: mode) { return run.count >= recipe.count }
        return mode == .higherLower && outcome.isCorrect == false
    }
}

/// Rebuilds the derived parts of a profile from the round history.
public enum ProfileRebuilder {
    /// Stats and daily state from `records` (in file order); taste from swipe records when
    /// `tasteBuckets` is given (otherwise `base.taste` is kept). Other fields come from `base`.
    public static func rebuild(
        from records: [RoundRecord], base: PlayerProfile, tasteBuckets: TasteBucketResolver?
    ) -> PlayerProfile {
        var accumulator = StatsAccumulator()
        var taste = TasteProfile()
        for record in records {
            accumulator.add(record)
            if let tasteBuckets, case .swipe(let round) = record.round, let liked = record.outcome.liked,
                let buckets = tasteBuckets(round.artwork)
            {
                taste = taste.applying(TasteSwipe(artworkID: round.artwork, buckets: buckets, liked: liked))
            }
        }
        var profile = base
        profile.stats = accumulator.stats
        profile.daily = accumulator.daily
        if tasteBuckets != nil { profile.taste = taste }
        return profile
    }
}

extension ProfileRebuilder {
    /// Rebuild from a whole log: stats, daily and taste as `rebuild(from:base:tasteBuckets:)`, then
    /// the last onboarding entry, if any, decides `prior`, `hasOnboarded` and the taste seeds
    /// (`complete` → prior + seeds + onboarded; `reset` → none of them). Without onboarding entries
    /// the base's prior, onboarding flag and seeds are kept.
    public static func rebuild(
        from log: RoundLogContents, base: PlayerProfile, tasteBuckets: TasteBucketResolver?
    ) -> PlayerProfile {
        var profile = rebuild(from: log.records, base: base, tasteBuckets: tasteBuckets)
        if let last = log.onboarding.last {
            switch last.action {
            case .complete:
                profile.hasOnboarded = true
                profile.prior = last.prior
                profile.taste = profile.taste.seeded(from: last.prior ?? .none)
            case .reset:
                profile.hasOnboarded = false
                profile.prior = nil
                profile.taste = profile.taste.seeded(from: .none)
            }
        } else if tasteBuckets != nil {
            profile.taste = profile.taste.restoringSeeds(base.taste.seeds)
        }
        return profile
    }
}

extension TastePrior {
    /// A prior with no preferences and no seed buckets (`seeded(from: .none)` removes seeds).
    public static let none = TastePrior(
        departmentWeights: [:], subjectWeights: [:], moodWeights: [:], defaultDifficulty: .medium,
        highlightedMode: .pickPrice, seedBuckets: [])
}

extension TasteProfile {
    /// Adds back seed pseudo-counts recorded in another profile (used when swipes were rebuilt
    /// from history but the seeds came from `profile.json`).
    func restoringSeeds(_ seeds: [String: Int]) -> TasteProfile {
        var p = self.seeded(from: .none)
        for (b, n) in seeds where n > 0 {
            p.seeds[b] = n
            p.exposures[b, default: 0] += n
            p.likes[b, default: 0] += n
        }
        return p
    }
}

extension DatasetProviding {
    /// A resolver for `ProfileRebuilder` / `FileProfileStore` backed by this dataset's pool.
    public var tasteBucketResolver: TasteBucketResolver {
        let pool = self.pool
        return { id in pool.artwork(id).map { TasteBuckets.buckets(for: $0) } }
    }
}
