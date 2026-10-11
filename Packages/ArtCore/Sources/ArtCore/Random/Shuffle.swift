/// Explicit Fisher–Yates (Durstenfeld) shuffle driven by `SplitMix64`.
///
/// For `i` from `count − 1` down to `1`: `j = rng.nextInt(i + 1)`, swap elements `i` and `j`.
/// Arrays of length 0 or 1 consume no randomness. Never use the standard library's
/// built-in random shuffle; its algorithm is unspecified and would not match other platforms.
public func shuffle<T>(_ array: inout [T], using rng: inout SplitMix64) {
    var i = array.count - 1
    while i > 0 {
        let j = rng.nextInt(i + 1)
        array.swapAt(i, j)
        i -= 1
    }
}

/// Returns a Fisher–Yates shuffled copy of `array` (see `shuffle(_:using:)`).
public func shuffled<T>(_ array: [T], using rng: inout SplitMix64) -> [T] {
    var copy = array
    shuffle(&copy, using: &rng)
    return copy
}
