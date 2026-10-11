/// Minimal Double math for display-only values (taste, rarity, "3.1× under").
///
/// ArtCore has no Foundation and the standard library has no `log`/`exp`, so these are
/// implemented here with range reduction + series (relative error ≈ 1e-15). Never use them for
/// selection or scoring.
public enum DisplayMath {
    public static let ln2 = 0.693_147_180_559_945_309_417_232_121_458
    public static let ln10 = 2.302_585_092_994_045_684_017_991_454_684

    /// Natural logarithm. Returns -infinity for 0 and NaN for negative or NaN input.
    public static func ln(_ x: Double) -> Double {
        if x.isNaN || x < 0 { return .nan }
        if x == 0 { return -.infinity }
        if x.isInfinite { return .infinity }
        // x = m · 2^e with m in [1, 2); fold m into [√½, √2) for faster convergence.
        var e = Double(x.exponent)
        var m = x.significand
        if m > 1.414_213_562_373_095 {
            m /= 2
            e += 1
        }
        // ln m = 2·atanh(z), z = (m−1)/(m+1), |z| ≤ 0.172.
        let z = (m - 1) / (m + 1)
        let z2 = z * z
        var term = z
        var sum = 0.0
        var k = 1.0
        while true {
            let add = term / k
            let next = sum + add
            if next == sum { break }
            sum = next
            term *= z2
            k += 2
        }
        return 2 * sum + e * ln2
    }

    /// e^x.
    public static func exp(_ x: Double) -> Double {
        if x.isNaN { return .nan }
        if x > 709.78 { return .infinity }
        if x < -745.2 { return 0 }
        // x = k·ln2 + r with |r| ≤ ln2/2.
        let k = (x / ln2).rounded()
        let r = x - k * ln2
        var term = 1.0
        var sum = 1.0
        var n = 1.0
        while true {
            term *= r / n
            let next = sum + term
            if next == sum { break }
            sum = next
            n += 1
        }
        return scale(sum, byPowerOfTwo: Int(k))
    }

    /// 10^x.
    public static func pow10(_ x: Double) -> Double {
        exp(x * ln10)
    }

    /// log10(x).
    public static func log10(_ x: Double) -> Double {
        ln(x) / ln10
    }

    static func scale(_ value: Double, byPowerOfTwo k: Int) -> Double {
        var result = value
        var remaining = k
        // Step in chunks so intermediate exponents stay representable.
        while remaining > 1000 {
            result *= Double(sign: .plus, exponent: 1000, significand: 1)
            remaining -= 1000
        }
        while remaining < -1000 {
            result *= Double(sign: .plus, exponent: -1000, significand: 1)
            remaining += 1000
        }
        return result * Double(sign: .plus, exponent: remaining, significand: 1)
    }
}
