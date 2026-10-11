/// Preferences derived from onboarding (plan Part I3). Integer weights: preferred = 3, everything
/// else = 1 (never 0), so the prior biases sampling without excluding anything.
public struct TastePrior: Codable, Sendable, Equatable {
    public static let preferredWeight = 3
    public static let defaultWeight = 1
    /// Pseudo-exposures (S_d and L_d) given to each seed bucket.
    public static let seedCount = 2

    /// Only preferred departments are stored; others weigh `defaultWeight`.
    public var departmentWeights: [DepartmentID: Int]
    /// Keyed by taste subject (`portrait`, `landscape`, …); missing = `defaultWeight`.
    public var subjectWeights: [String: Int]
    /// Keyed by taste mood (`serene`, `dramatic`, …); missing = `defaultWeight`.
    public var moodWeights: [String: Int]
    public var defaultDifficulty: Difficulty
    /// The mode tile Home highlights.
    public var highlightedMode: GameMode
    /// Taste buckets that receive pseudo-exposures (sorted, UTF-8 order).
    public var seedBuckets: [String]

    public init(
        departmentWeights: [DepartmentID: Int], subjectWeights: [String: Int], moodWeights: [String: Int],
        defaultDifficulty: Difficulty, highlightedMode: GameMode, seedBuckets: [String]
    ) {
        self.departmentWeights = departmentWeights
        self.subjectWeights = subjectWeights
        self.moodWeights = moodWeights
        self.defaultDifficulty = defaultDifficulty
        self.highlightedMode = highlightedMode
        self.seedBuckets = seedBuckets
    }

    enum CodingKeys: String, CodingKey {
        case departmentWeights = "department_weights"
        case subjectWeights = "subject_weights"
        case moodWeights = "mood_weights"
        case defaultDifficulty = "default_difficulty"
        case highlightedMode = "highlighted_mode"
        case seedBuckets = "seed_buckets"
    }

    /// Builds the prior (pure).
    ///
    /// - Preferred departments: the chosen departments, else the era's departments
    ///   (classic → old_masters + nineteenth_century; modern → impressionist_modern).
    /// - Subjects and mood map to taste subjects/moods (`OnboardingAnswers.Subject.tasteSubjects`,
    ///   `Mood.tasteMoods`), each weighted 3.
    /// - Intent: learn → easy + category; play → medium + pick_price; test my eye → hard + bid;
    ///   none → medium + pick_price.
    /// - Seed buckets: `era:` buckets of the preferred departments (`Department.typicalEraBuckets`),
    ///   `subject:` and `mood:` buckets of the chosen subjects and mood.
    public static func from(answers: OnboardingAnswers) -> TastePrior {
        let preferred: [DepartmentID] =
            answers.departments.isEmpty ? (answers.era?.departments ?? []) : answers.departments.sorted()
        var departmentWeights: [DepartmentID: Int] = [:]
        for d in preferred { departmentWeights[d] = preferredWeight }
        var subjectWeights: [String: Int] = [:]
        for s in answers.subjects { for t in s.tasteSubjects { subjectWeights[t] = preferredWeight } }
        var moodWeights: [String: Int] = [:]
        for m in answers.mood?.tasteMoods ?? [] { moodWeights[m] = preferredWeight }

        let difficulty: Difficulty
        let mode: GameMode
        switch answers.intent {
        case .learn?: (difficulty, mode) = (.easy, .category)
        case .testMyEye?: (difficulty, mode) = (.hard, .bid)
        case .play?, nil: (difficulty, mode) = (.medium, .pickPrice)
        }

        var seeds = Set<String>()
        for d in preferred { for e in Department.typicalEraBuckets[d] ?? [] { seeds.insert("era:" + e) } }
        for t in subjectWeights.keys { seeds.insert("subject:" + t) }
        for m in moodWeights.keys { seeds.insert("mood:" + m) }
        return TastePrior(
            departmentWeights: departmentWeights, subjectWeights: subjectWeights, moodWeights: moodWeights,
            defaultDifficulty: difficulty, highlightedMode: mode, seedBuckets: seeds.sorted(by: utf8Less))
    }

    /// Department weight (missing → 1; non-positive stored values are treated as 1).
    public func weight(forDepartment d: DepartmentID?) -> Int {
        guard let d, let w = departmentWeights[d], w > 0 else { return Self.defaultWeight }
        return w
    }

    /// Sampling weight of an artwork: department weight + subject weight + mood weight (3…9), so a
    /// full match is 3× a non-match.
    public func weight(for artwork: Artwork, in pool: GamePool) -> Int {
        func w(_ table: [String: Int], _ key: String) -> Int {
            guard let v = table[key], v > 0 else { return Self.defaultWeight }
            return v
        }
        return weight(forDepartment: pool.department(of: artwork)) + w(subjectWeights, artwork.taste.subject)
            + w(moodWeights, artwork.taste.mood)
    }

    /// Departments weighted above the default, sorted.
    public var preferredDepartments: [DepartmentID] {
        departmentWeights.filter { $0.value > Self.defaultWeight }.map(\.key).sorted()
    }
}
