/// Category quiz question generator (Part E6 distractor rules).
public enum CategoryQuestionGenerator {
    /// Era gap (years) at or under which two categories are "era-adjacent".
    public static let adjacentYears = 60
    /// Era gap (years) above which two categories are "far".
    public static let farYears = 150

    /// Distractor slot types.
    public enum Slot: String, Sendable, Codable {
        case neighbour, confuser, eraAdjacent = "era_adjacent", far
    }

    /// Slots by difficulty: easy = 1 era-adjacent + 2 far; medium = 1 neighbour + 2 era-adjacent;
    /// hard = 2 neighbours + 1 confuser.
    public static func slots(for difficulty: Difficulty) -> [Slot] {
        switch difficulty {
        case .easy: [.eraAdjacent, .far, .far]
        case .medium: [.neighbour, .eraAdjacent, .eraAdjacent]
        case .hard: [.neighbour, .neighbour, .confuser]
        }
    }

    /// The category the question asks for: the primary category if quiz-eligible, else the first
    /// quiz-eligible accepted alternate; nil if none.
    public static func truthCategory(for artwork: Artwork, pool: GamePool) -> Category? {
        for id in artwork.allCategories where pool.quizCategoryIDs.contains(id) {
            return pool.category(id)
        }
        return nil
    }

    /// Builds a question.
    ///
    /// Candidates: **active** categories (sorted by id; they need not be quiz-eligible) excluding the truth, every category of
    /// the work (primary + accepted), medium-axis categories when the truth is a movement, and the
    /// truth's parent/children unless difficulty is hard. For each slot in order: pick
    /// `bucket[nextInt(bucket.count)]` from unchosen candidates matching the slot; if none match,
    /// pick from all unchosen candidates the same way. Then the truth goes at `s = nextInt(4)`.
    public static func make(artwork: Artwork, pool: GamePool, difficulty: Difficulty, rng: inout SplitMix64)
        throws -> CategoryRound
    {
        guard let truth = truthCategory(for: artwork, pool: pool) else {
            throw GenerationError.noQuizCategory(artwork.id)
        }
        let workCategories = Set(artwork.allCategories)
        let candidates = pool.categories.filter { c in
            guard pool.activeCategoryIDs.contains(c.id), c.id != truth.id, !workCategories.contains(c.id) else {
                return false
            }
            if truth.axis == .movement && c.axis == .medium { return false }
            if difficulty != .hard && (c.parent == truth.id || truth.parent == c.id) { return false }
            return true
        }
        var chosen: [Category] = []
        for slot in slots(for: difficulty) {
            let open = candidates.filter { c in !chosen.contains { $0.id == c.id } }
            guard !open.isEmpty else { throw GenerationError.notEnoughDistractors(artwork.id) }
            let bucket = open.filter { matches($0, slot: slot, truth: truth) }
            let source = bucket.isEmpty ? open : bucket
            chosen.append(source[rng.nextInt(source.count)])
        }
        let s = rng.nextInt(4)
        var options = chosen.map(\.id)
        options.insert(truth.id, at: s)
        let accepted = artwork.allCategories.filter { $0 != truth.id }
        return CategoryRound(
            artwork: artwork.id, options: options, correctIndex: s, accepted: accepted, difficulty: difficulty)
    }

    /// Slot membership. Neighbour is symmetric (either lists the other).
    public static func matches(_ c: Category, slot: Slot, truth: Category) -> Bool {
        switch slot {
        case .neighbour: truth.neighbours.contains(c.id) || c.neighbours.contains(truth.id)
        case .confuser: truth.confusers.contains(c.id)
        case .eraAdjacent: truth.era.gap(to: c.era) <= adjacentYears
        case .far: truth.era.gap(to: c.era) > farYears
        }
    }
}
