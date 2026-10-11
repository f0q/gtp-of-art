import ArtCore

// Input/expected shapes of every fixture file. JSON keys are snake_case; 64-bit unsigned values
// are decimal strings. Kotlin mirrors these shapes.

public enum PRNGFixture {
    public struct Input: Codable, Sendable {
        public var seed: String
        public var count: Int
        /// When present, values are `nextInt(bound)` results; otherwise raw `next()` outputs.
        public var bound: String?
        public init(seed: String, count: Int, bound: String?) {
            self.seed = seed
            self.count = count
            self.bound = bound
        }
    }
    public struct Expected: Codable, Sendable {
        public var values: [String]
        public var stateAfter: String
        public init(values: [String], stateAfter: String) {
            self.values = values
            self.stateAfter = stateAfter
        }
        enum CodingKeys: String, CodingKey {
            case values
            case stateAfter = "state_after"
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}

public enum ShuffleFixture {
    public struct Input: Codable, Sendable {
        public var seed: String
        /// Shuffle the array `[0, 1, …, n−1]`.
        public var n: Int
        public init(seed: String, n: Int) {
            self.seed = seed
            self.n = n
        }
    }
    public struct Expected: Codable, Sendable {
        public var permutation: [Int]
        public var stateAfter: String
        public init(permutation: [Int], stateAfter: String) {
            self.permutation = permutation
            self.stateAfter = stateAfter
        }
        enum CodingKeys: String, CodingKey {
            case permutation
            case stateAfter = "state_after"
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}

public enum FNVFixture {
    public struct Input: Codable, Sendable {
        public var text: String
        public init(text: String) { self.text = text }
    }
    public struct Expected: Codable, Sendable {
        public var hash: String
        public var hashHex: String
        public init(hash: String, hashHex: String) {
            self.hash = hash
            self.hashHex = hashHex
        }
        enum CodingKeys: String, CodingKey {
            case hash
            case hashHex = "hash_hex"
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}

public enum DayKeyFixture {
    public struct Input: Codable, Sendable {
        public var year: Int
        public var month: Int
        public var day: Int
        public init(year: Int, month: Int, day: Int) {
            self.year = year
            self.month = month
            self.day = day
        }
    }
    public struct Expected: Codable, Sendable {
        public var valid: Bool
        /// Present only when valid.
        public var dayNumber: Int?
        public var iso: String?
        public init(valid: Bool, dayNumber: Int?, iso: String?) {
            self.valid = valid
            self.dayNumber = dayNumber
            self.iso = iso
        }
        enum CodingKeys: String, CodingKey {
            case valid
            case dayNumber = "day_number"
            case iso
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}

public enum StreakFixture {
    public struct Input: Codable, Sendable {
        public var streak: Int
        public var lastDay: String?
        public var today: String
        public init(streak: Int, lastDay: String?, today: String) {
            self.streak = streak
            self.lastDay = lastDay
            self.today = today
        }
        enum CodingKeys: String, CodingKey {
            case streak
            case lastDay = "last_day"
            case today
        }
    }
    public struct Expected: Codable, Sendable {
        public var streak: Int
        public var lastDay: String?
        public init(streak: Int, lastDay: String?) {
            self.streak = streak
            self.lastDay = lastDay
        }
        enum CodingKeys: String, CodingKey {
            case streak
            case lastDay = "last_day"
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}

public enum DailyFixture {
    public struct Input: Codable, Sendable {
        public var day: String
        public var datasetVersion: String
        public var rulesVersion: Int
        public init(day: String, datasetVersion: String, rulesVersion: Int) {
            self.day = day
            self.datasetVersion = datasetVersion
            self.rulesVersion = rulesVersion
        }
        enum CodingKeys: String, CodingKey {
            case day
            case datasetVersion = "dataset_version"
            case rulesVersion = "rules_version"
        }
    }
    public struct Expected: Codable, Sendable {
        public var seedString: String
        public var seed: String
        public var rounds: [Round]
        public init(seedString: String, seed: String, rounds: [Round]) {
            self.seedString = seedString
            self.seed = seed
            self.rounds = rounds
        }
        enum CodingKeys: String, CodingKey {
            case seedString = "seed_string"
            case seed, rounds
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}

public enum DistractorFixture {
    public struct Input: Codable, Sendable {
        public var truthUSD: Int64
        public var difficulty: Difficulty
        public var seed: String
        public init(truthUSD: Int64, difficulty: Difficulty, seed: String) {
            self.truthUSD = truthUSD
            self.difficulty = difficulty
            self.seed = seed
        }
        enum CodingKeys: String, CodingKey {
            case truthUSD = "truth_usd"
            case difficulty, seed
        }
    }
    public struct Expected: Codable, Sendable {
        public var options: [Int64]?
        public var correctIndex: Int?
        public var usedFallback: Bool?
        /// Error code when generation fails.
        public var error: String?
        public var stateAfter: String
        public init(options: [Int64]?, correctIndex: Int?, usedFallback: Bool?, error: String?, stateAfter: String) {
            self.options = options
            self.correctIndex = correctIndex
            self.usedFallback = usedFallback
            self.error = error
            self.stateAfter = stateAfter
        }
        enum CodingKeys: String, CodingKey {
            case options
            case correctIndex = "correct_index"
            case usedFallback = "used_fallback"
            case error
            case stateAfter = "state_after"
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}

public enum BidFixture {
    public struct Input: Codable, Sendable {
        public var position: Int
        public var actualMilli: Int
        public init(position: Int, actualMilli: Int) {
            self.position = position
            self.actualMilli = actualMilli
        }
        enum CodingKeys: String, CodingKey {
            case position
            case actualMilli = "actual_milli"
        }
    }
    public struct Expected: Codable, Sendable {
        public var guessMilli: Int
        public var errorMilli: Int
        public var tier: BidTier
        public var points: Int
        public var direction: BidDirection
        /// Display-only, compare within `factorTolerance` (relative).
        public var factor: Double
        public var factorTolerance: Double
        public init(
            guessMilli: Int, errorMilli: Int, tier: BidTier, points: Int, direction: BidDirection, factor: Double,
            factorTolerance: Double
        ) {
            self.guessMilli = guessMilli
            self.errorMilli = errorMilli
            self.tier = tier
            self.points = points
            self.direction = direction
            self.factor = factor
            self.factorTolerance = factorTolerance
        }
        enum CodingKeys: String, CodingKey {
            case guessMilli = "guess_milli"
            case errorMilli = "error_milli"
            case tier, points, direction, factor
            case factorTolerance = "factor_tolerance"
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}

public enum PairFixture {
    public struct Input: Codable, Sendable {
        public var difficulty: Difficulty
        public var yearWindow: Int?
        public var used: [String]
        public var anchor: String?
        public var seed: String
        public init(difficulty: Difficulty, yearWindow: Int?, used: [String], anchor: String?, seed: String) {
            self.difficulty = difficulty
            self.yearWindow = yearWindow
            self.used = used
            self.anchor = anchor
            self.seed = seed
        }
        enum CodingKeys: String, CodingKey {
            case difficulty
            case yearWindow = "year_window"
            case used, anchor, seed
        }
    }
    public struct Expected: Codable, Sendable {
        public var round: HigherLowerRound?
        public var error: String?
        public var stateAfter: String
        public init(round: HigherLowerRound?, error: String?, stateAfter: String) {
            self.round = round
            self.error = error
            self.stateAfter = stateAfter
        }
        enum CodingKeys: String, CodingKey {
            case round, error
            case stateAfter = "state_after"
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}

public enum CategoryFixture {
    public struct Input: Codable, Sendable {
        public var artworkID: String
        public var difficulty: Difficulty
        public var seed: String
        public init(artworkID: String, difficulty: Difficulty, seed: String) {
            self.artworkID = artworkID
            self.difficulty = difficulty
            self.seed = seed
        }
        enum CodingKeys: String, CodingKey {
            case artworkID = "artwork_id"
            case difficulty, seed
        }
    }
    public struct Expected: Codable, Sendable {
        public var round: CategoryRound?
        public var error: String?
        public var stateAfter: String
        public init(round: CategoryRound?, error: String?, stateAfter: String) {
            self.round = round
            self.error = error
            self.stateAfter = stateAfter
        }
        enum CodingKeys: String, CodingKey {
            case round, error
            case stateAfter = "state_after"
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}

public enum TasteFixture {
    public struct SwipeInput: Codable, Sendable {
        public var artworkID: String
        public var liked: Bool
        public init(artworkID: String, liked: Bool) {
            self.artworkID = artworkID
            self.liked = liked
        }
        enum CodingKeys: String, CodingKey {
            case artworkID = "artwork_id"
            case liked
        }
    }
    public struct Input: Codable, Sendable {
        /// Applied in order to an empty profile, using the mini dataset and its baseline.
        public var swipes: [SwipeInput]
        /// Undo this many swipes from the end after applying all of them.
        public var undoLast: Int
        public init(swipes: [SwipeInput], undoLast: Int) {
            self.swipes = swipes
            self.undoLast = undoLast
        }
        enum CodingKeys: String, CodingKey {
            case swipes
            case undoLast = "undo_last"
        }
    }
    public struct Expected: Codable, Sendable {
        public var profile: TasteProfile
        public var distinctiveness: Double
        public var axes: TasteAxes
        public var archetypeID: String
        /// The three buckets with the largest |c_d|.
        public var topBuckets: [String]
        /// Absolute tolerance for Double fields.
        public var tolerance: Double
        public init(
            profile: TasteProfile, distinctiveness: Double, axes: TasteAxes, archetypeID: String,
            topBuckets: [String], tolerance: Double
        ) {
            self.profile = profile
            self.distinctiveness = distinctiveness
            self.axes = axes
            self.archetypeID = archetypeID
            self.topBuckets = topBuckets
            self.tolerance = tolerance
        }
        enum CodingKeys: String, CodingKey {
            case profile, distinctiveness, axes
            case archetypeID = "archetype_id"
            case topBuckets = "top_buckets"
            case tolerance
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}

public enum RarityFixture {
    public struct Input: Codable, Sendable {
        public var distinctiveness: Double
        public var swipeCount: Int
        public var archetypeID: String
        public init(distinctiveness: Double, swipeCount: Int, archetypeID: String) {
            self.distinctiveness = distinctiveness
            self.swipeCount = swipeCount
            self.archetypeID = archetypeID
        }
        enum CodingKeys: String, CodingKey {
            case distinctiveness
            case swipeCount = "swipe_count"
            case archetypeID = "archetype_id"
        }
    }
    public struct Expected: Codable, Sendable {
        public var visibility: RarityVisibility
        public var swipeBucket: Int?
        public var percentile: Double
        public var band: RarityBand
        public var archetypeShare: Double?
        public var editionNumber: Int?
        /// Absolute tolerance for `percentile` (±0.5).
        public var tolerance: Double
        public init(
            visibility: RarityVisibility, swipeBucket: Int?, percentile: Double, band: RarityBand,
            archetypeShare: Double?, editionNumber: Int?, tolerance: Double
        ) {
            self.visibility = visibility
            self.swipeBucket = swipeBucket
            self.percentile = percentile
            self.band = band
            self.archetypeShare = archetypeShare
            self.editionNumber = editionNumber
            self.tolerance = tolerance
        }
        enum CodingKeys: String, CodingKey {
            case visibility
            case swipeBucket = "swipe_bucket"
            case percentile, band
            case archetypeShare = "archetype_share"
            case editionNumber = "edition_number"
            case tolerance
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}

public enum PriceFormatFixture {
    public struct Input: Codable, Sendable {
        public var usd: Int64
        public var approximate: Bool
        public var reported: Bool
        public var lowerBound: Bool
        public init(usd: Int64, approximate: Bool, reported: Bool, lowerBound: Bool) {
            self.usd = usd
            self.approximate = approximate
            self.reported = reported
            self.lowerBound = lowerBound
        }
        enum CodingKeys: String, CodingKey {
            case usd, approximate, reported
            case lowerBound = "lower_bound"
        }
    }
    public struct Expected: Codable, Sendable {
        public var rounded: Int64
        public var compact: String
        public var text: String
        public init(rounded: Int64, compact: String, text: String) {
            self.rounded = rounded
            self.compact = compact
            self.text = text
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}

public enum WeightedPickFixture {
    public struct Input: Codable, Sendable {
        public var weights: [Int]
        public var seed: String
        /// Number of independent picks from the same stream.
        public var count: Int
        public init(weights: [Int], seed: String, count: Int) {
            self.weights = weights
            self.seed = seed
            self.count = count
        }
    }
    public struct Expected: Codable, Sendable {
        /// Picked indices; absent when the total weight is 0 (no draw is made).
        public var picks: [Int]?
        public var stateAfter: String
        public init(picks: [Int]?, stateAfter: String) {
            self.picks = picks
            self.stateAfter = stateAfter
        }
        enum CodingKeys: String, CodingKey {
            case picks
            case stateAfter = "state_after"
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}

public enum PriorFixture {
    public struct Input: Codable, Sendable {
        public var answers: OnboardingAnswers
        public var mode: GameMode
        /// Custom recipe (absent = mode default).
        public var recipe: [RoundSpec]?
        public var seed: String
        public init(answers: OnboardingAnswers, mode: GameMode, recipe: [RoundSpec]?, seed: String) {
            self.answers = answers
            self.mode = mode
            self.recipe = recipe
            self.seed = seed
        }
    }
    public struct Expected: Codable, Sendable {
        public var prior: TastePrior
        /// `TasteProfile().seeded(from: prior)`.
        public var seededProfile: TasteProfile
        /// Rounds of `GameSession.make(mode:recipe:pool:seed:prior:)` (first batch for endless modes).
        public var rounds: [Round]
        public init(prior: TastePrior, seededProfile: TasteProfile, rounds: [Round]) {
            self.prior = prior
            self.seededProfile = seededProfile
            self.rounds = rounds
        }
        enum CodingKeys: String, CodingKey {
            case prior
            case seededProfile = "seeded_profile"
            case rounds
        }
    }
    public typealias File = FixtureFile<Input, Expected>
}
