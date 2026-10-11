/// Deterministic weighted choice with integer weights.
public enum WeightedPicker {
    /// Returns an index `i` with probability `weights[i] / Σ weights`, or nil when the total is 0.
    ///
    /// Negative weights count as 0; zero-weight indices are never returned.
    /// `r = rng.nextInt(total)`; return the first `i` with `r < weights[0] + … + weights[i]`.
    /// Exactly one draw when the total is positive; none otherwise.
    public static func pick(weights: [Int], rng: inout SplitMix64) -> Int? {
        var total = 0
        for w in weights where w > 0 { total += w }
        guard total > 0 else { return nil }
        let r = rng.nextInt(total)
        var cumulative = 0
        for (i, w) in weights.enumerated() where w > 0 {
            cumulative += w
            if r < cumulative { return i }
        }
        return nil  // unreachable
    }
}
