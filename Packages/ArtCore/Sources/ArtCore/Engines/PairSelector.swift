/// Which stacked frame holds the pricier work.
public enum PricierSide: String, Codable, Sendable, CaseIterable {
    case top, bottom
}

/// One pass of pair constraints.
public struct PairConstraints: Sendable, Equatable, Codable {
    /// Minimum |Δ log10_usd_adjusted_milli|.
    public var minGapMilli: Int
    /// Both works must share a category (primary or accepted alternate).
    public var requireSharedCategory: Bool
    /// Maximum |Δ creation year|; nil = no era constraint.
    public var maxYearGap: Int?
    /// When set, both works must be in the same department and it must be one of these
    /// (sorted). Only checked when a pool is available (`PairSelector.select`).
    public var departments: [DepartmentID]?

    public init(minGapMilli: Int, requireSharedCategory: Bool, maxYearGap: Int?) {
        self.init(minGapMilli: minGapMilli, requireSharedCategory: requireSharedCategory, maxYearGap: maxYearGap, departments: nil)
    }

    public init(minGapMilli: Int, requireSharedCategory: Bool, maxYearGap: Int?, departments: [DepartmentID]?) {
        self.minGapMilli = minGapMilli
        self.requireSharedCategory = requireSharedCategory
        self.maxYearGap = maxYearGap
        self.departments = departments
    }
}

/// "Which is pricier?" pair selection using `log10_usd_adjusted_milli` (today's dollars).
public enum PairSelector {
    /// Candidate pairs examined per pass before relaxing.
    public static let candidateCap = 2000
    /// Era window used when a round asks for one.
    public static let defaultYearWindow = 60

    /// Minimum gap: easy 1000 (10×), medium 477 (3×), hard 301 (2×).
    public static func minGapMilli(_ difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: 1000
        case .medium: 477
        case .hard: 301
        }
    }

    /// Ordered constraint passes: requested (with era) → requested without era → each easier
    /// difficulty level without era → floor (301, no shared category). Consecutive duplicates removed.
    /// Relaxation order: era first, then difficulty.
    public static func passes(difficulty: Difficulty, yearWindow: Int?) -> [PairConstraints] {
        let levels: [PairConstraints]
        switch difficulty {
        case .easy:
            levels = [
                PairConstraints(minGapMilli: 1000, requireSharedCategory: false, maxYearGap: nil),
                PairConstraints(minGapMilli: 477, requireSharedCategory: false, maxYearGap: nil),
                PairConstraints(minGapMilli: 301, requireSharedCategory: false, maxYearGap: nil),
            ]
        case .medium:
            levels = [
                PairConstraints(minGapMilli: 477, requireSharedCategory: false, maxYearGap: nil),
                PairConstraints(minGapMilli: 301, requireSharedCategory: false, maxYearGap: nil),
            ]
        case .hard:
            levels = [
                PairConstraints(minGapMilli: 301, requireSharedCategory: true, maxYearGap: nil),
                PairConstraints(minGapMilli: 301, requireSharedCategory: false, maxYearGap: nil),
            ]
        }
        var result: [PairConstraints] = []
        if let yearWindow {
            var first = levels[0]
            first.maxYearGap = yearWindow
            result.append(first)
        }
        for level in levels where result.last != level {
            result.append(level)
        }
        return result
    }

    /// Passes with a soft department preference: each base pass is first tried restricted to a
    /// same-department pair in one of `preferredDepartments`, then unrestricted. The department is
    /// therefore the first thing relaxed at every level. Empty preference → base passes.
    public static func passes(difficulty: Difficulty, yearWindow: Int?, preferredDepartments: [DepartmentID])
        -> [PairConstraints]
    {
        let base = passes(difficulty: difficulty, yearWindow: yearWindow)
        guard !preferredDepartments.isEmpty else { return base }
        let sortedDepartments = preferredDepartments.sorted()
        var result: [PairConstraints] = []
        for pass in base {
            var restricted = pass
            restricted.departments = sortedDepartments
            result.append(restricted)
            result.append(pass)
        }
        return result
    }

    /// Selects a pair.
    ///
    /// 1. Eligible = pool works with a game price, not in `used`, not the anchor; sorted by id.
    /// 2. Shuffle eligible indices once (Fisher–Yates).
    /// 3. For each pass: scan candidates in order — without an anchor the pairs `(perm[i], perm[j])`
    ///    for `i < j` (row-major); with an anchor the pairs `(anchor, perm[k])` — examining at most
    ///    2000 per pass; accept the first pair meeting the pass constraints.
    /// 4. Without an anchor, `nextInt(2) == 0` puts the pricier work on top; with an anchor the
    ///    anchor is always on top (higher-or-lower chaining) and no number is drawn.
    public static func select(
        pool: GamePool, difficulty: Difficulty, yearWindow: Int?, used: Set<ArtworkID>,
        anchor: ArtworkID? = nil, prior: TastePrior? = nil, rng: inout SplitMix64
    ) throws -> HigherLowerRound {
        var anchorWork: Artwork?
        if let anchor {
            guard let a = pool.artwork(anchor), a.gamePrice != nil else {
                throw GenerationError.invalidAnchor(anchor)
            }
            anchorWork = a
        }
        let eligible = pool.artworks.filter { $0.gamePrice != nil && !used.contains($0.id) && $0.id != anchor }
        var perm = Array(eligible.indices)
        shuffle(&perm, using: &rng)

        let allPasses = passes(
            difficulty: difficulty, yearWindow: yearWindow, preferredDepartments: prior?.preferredDepartments ?? [])
        for (passIndex, constraints) in allPasses.enumerated() {
            if let (a, b) = scan(eligible: eligible, perm: perm, anchor: anchorWork, constraints: constraints, pool: pool) {
                let aMilli = a.gamePrice!.log10UsdAdjustedMilli
                let bMilli = b.gamePrice!.log10UsdAdjustedMilli
                let top: Artwork
                let bottom: Artwork
                if anchorWork != nil {
                    top = a
                    bottom = b
                } else {
                    let pricierOnTop = rng.nextInt(2) == 0
                    let (hi, lo) = aMilli > bMilli ? (a, b) : (b, a)
                    (top, bottom) = pricierOnTop ? (hi, lo) : (lo, hi)
                }
                let topMilli = top.gamePrice!.log10UsdAdjustedMilli
                let bottomMilli = bottom.gamePrice!.log10UsdAdjustedMilli
                return HigherLowerRound(
                    top: top.id, bottom: bottom.id, topMilli: topMilli, bottomMilli: bottomMilli,
                    pricierSide: topMilli > bottomMilli ? .top : .bottom, relaxation: passIndex,
                    difficulty: difficulty)
            }
        }
        throw GenerationError.poolExhausted(.higherLower)
    }

    static func scan(eligible: [Artwork], perm: [Int], anchor: Artwork?, constraints: PairConstraints, pool: GamePool)
        -> (Artwork, Artwork)?
    {
        var examined = 0
        if let anchor {
            for k in perm.indices {
                examined += 1
                if examined > candidateCap { return nil }
                let b = eligible[perm[k]]
                if accepts(anchor, b, constraints, pool: pool) { return (anchor, b) }
            }
            return nil
        }
        for i in perm.indices {
            for j in (i + 1)..<perm.count {
                examined += 1
                if examined > candidateCap { return nil }
                let a = eligible[perm[i]]
                let b = eligible[perm[j]]
                if accepts(a, b, constraints, pool: pool) { return (a, b) }
            }
        }
        return nil
    }

    /// True if the pair satisfies `constraints`, including the department restriction.
    public static func accepts(_ a: Artwork, _ b: Artwork, _ constraints: PairConstraints, pool: GamePool) -> Bool {
        if let allowed = constraints.departments {
            guard let da = pool.department(of: a), da == pool.department(of: b), allowed.contains(da) else {
                return false
            }
        }
        return accepts(a, b, constraints)
    }

    /// True if the pair satisfies `constraints` (gap, shared category, era). The department
    /// restriction needs a pool and is ignored here.
    public static func accepts(_ a: Artwork, _ b: Artwork, _ constraints: PairConstraints) -> Bool {
        guard let pa = a.gamePrice, let pb = b.gamePrice else { return false }
        if abs(pa.log10UsdAdjustedMilli - pb.log10UsdAdjustedMilli) < constraints.minGapMilli { return false }
        if constraints.requireSharedCategory {
            let shared = a.allCategories.contains { b.allCategories.contains($0) }
            if !shared { return false }
        }
        if let window = constraints.maxYearGap {
            guard let ya = a.year, let yb = b.year, abs(ya - yb) <= window else { return false }
        }
        return true
    }
}
