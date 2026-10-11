/// A rational step multiplier `num/den` used to space price options.
public struct StepRatio: Sendable, Equatable, Codable {
    public var num: Int64
    public var den: Int64
    public init(_ num: Int64, _ den: Int64 = 1) {
        self.num = num
        self.den = den
    }
}

/// Four ascending price options with the index of the truth.
public struct PriceOptions: Sendable, Equatable, Codable {
    public var options: [Int64]
    public var correctIndex: Int
    /// True when the 8 random attempts failed and the deterministic fallback produced the set.
    public var usedFallback: Bool

    public init(options: [Int64], correctIndex: Int, usedFallback: Bool) {
        self.options = options
        self.correctIndex = correctIndex
        self.usedFallback = usedFallback
    }

    enum CodingKeys: String, CodingKey {
        case options
        case correctIndex = "correct_index"
        case usedFallback = "used_fallback"
    }
}

/// "Pick the price" option generator (integer-only, deterministic).
public enum PriceOptionGenerator {
    public static let minUSD: Int64 = 500
    public static let maxUSD: Int64 = 2_000_000_000
    public static let maxAttempts = 8
    /// Values a distractor may never take (they look like placeholders).
    public static let forbiddenDistractors: Set<Int64> = [1_000_000, 1_000_000_000]

    /// Step multipliers between adjacent options for a difficulty.
    public static func steps(for difficulty: Difficulty) -> [StepRatio] {
        switch difficulty {
        case .easy: [StepRatio(4), StepRatio(5), StepRatio(6)]
        case .medium: [StepRatio(5, 2), StepRatio(3), StepRatio(4)]
        case .hard: [StepRatio(2), StepRatio(5, 2)]
        }
    }

    /// Generates options for a truth price (whole USD).
    ///
    /// Up to 8 attempts: `s = nextInt(4)`; `v[s] = round2(truth)`; for `i = s+1…3`:
    /// `v[i] = v[i−1]·num/den` with a step drawn by `nextInt(steps.count)`; then for `i = s−1…0`:
    /// `v[i] = v[i+1]·den/num` likewise; round every value to 2 s.f.; accept if valid
    /// (`isValid`). Fallback: for `s = 0…3`, for each step in listed order, use that step
    /// everywhere (no randomness); first valid set wins.
    public static func make(truthUSD: Int64, difficulty: Difficulty, rng: inout SplitMix64) throws
        -> PriceOptions
    {
        let truth = SigFig.round2(max(0, truthUSD))
        guard truth >= minUSD, truth <= maxUSD else { throw GenerationError.priceOutOfBand(truthUSD) }
        let steps = steps(for: difficulty)
        for _ in 0..<maxAttempts {
            let s = rng.nextInt(4)
            let values = build(truth: truth, slot: s) { steps[rng.nextInt(steps.count)] }
            if isValid(values, correctIndex: s) {
                return PriceOptions(options: values, correctIndex: s, usedFallback: false)
            }
        }
        for s in 0..<4 {
            for step in steps {
                let values = build(truth: truth, slot: s) { step }
                if isValid(values, correctIndex: s) {
                    return PriceOptions(options: values, correctIndex: s, usedFallback: true)
                }
            }
        }
        throw GenerationError.noValidPriceOptions(truthUSD)
    }

    /// Builds the four values outward from `slot` (upward first, then downward), rounding each to 2 s.f.
    static func build(truth: Int64, slot: Int, nextStep: () -> StepRatio) -> [Int64] {
        var v = [Int64](repeating: 0, count: 4)
        v[slot] = truth
        var i = slot + 1
        while i < 4 {
            let r = nextStep()
            v[i] = v[i - 1] * r.num / r.den
            i += 1
        }
        i = slot - 1
        while i >= 0 {
            let r = nextStep()
            v[i] = v[i + 1] * r.den / r.num
            i -= 1
        }
        return v.map(SigFig.round2)
    }

    /// Constraints: every option in [$500, $2B]; adjacent options satisfy `a·18 ≤ b·10` (≥ 1.8×,
    /// which also makes them distinct and ascending); no distractor equals $1M or $1B.
    public static func isValid(_ values: [Int64], correctIndex: Int) -> Bool {
        guard values.count == 4 else { return false }
        for (i, v) in values.enumerated() {
            if v < minUSD || v > maxUSD { return false }
            if i != correctIndex && forbiddenDistractors.contains(v) { return false }
        }
        for i in 1..<4 where values[i - 1] * 18 > values[i] * 10 {
            return false
        }
        return true
    }
}
