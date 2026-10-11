/// SplitMix64 pseudo-random generator (Steele, Lea & Flood 2014; reference C by S. Vigna).
///
/// This is the only source of randomness in game selection. It is fully specified in
/// `spec/game-logic.md` so the Android port produces bit-identical streams.
/// All arithmetic wraps modulo 2^64.
public struct SplitMix64: Sendable, Hashable, Codable {
    /// The internal 64-bit state. After `n` calls to `next()` it equals `seed + n·0x9E3779B97F4A7C15 (mod 2^64)`.
    public private(set) var state: UInt64

    /// Golden-ratio increment added to the state on every step.
    public static let gamma: UInt64 = 0x9E37_79B9_7F4A_7C15

    /// Creates a generator whose first output is derived from `seed + gamma`.
    public init(seed: UInt64) {
        state = seed
    }

    /// Returns the next 64-bit output.
    public mutating func next() -> UInt64 {
        state &+= Self.gamma
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Returns a uniformly distributed integer in `0..<bound` without modulo bias.
    ///
    /// Rejection sampling: let `t = (2^64 − bound) mod bound` (= 2^64 mod bound).
    /// Draw `r = next()`; if `r < t` draw again; otherwise return `r mod bound`.
    /// - Precondition: `bound > 0`.
    public mutating func nextInt(_ bound: Int) -> Int {
        precondition(bound > 0, "nextInt bound must be positive")
        let b = UInt64(bound)
        let threshold = (0 &- b) % b
        while true {
            let r = next()
            if r >= threshold {
                return Int(r % b)
            }
        }
    }
}
