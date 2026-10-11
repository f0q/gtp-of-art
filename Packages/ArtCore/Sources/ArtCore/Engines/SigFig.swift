/// Integer significant-figure rounding.
public enum SigFig {
    /// Rounds a non-negative value to 2 significant figures, half up.
    ///
    /// Values below 100 are returned unchanged. Otherwise with `p = 10^(digits − 2)`:
    /// `((v + p/2) / p) · p` using integer division. Example: 1_950_000 → 2_000_000; 1_949_999 → 1_900_000.
    public static func round2(_ value: Int64) -> Int64 {
        precondition(value >= 0, "SigFig.round2 expects a non-negative value")
        guard value >= 100 else { return value }
        var p: Int64 = 1
        var v = value
        while v >= 100 {
            v /= 10
            p *= 10
        }
        return ((value + p / 2) / p) * p
    }
}
