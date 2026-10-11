/// One bucket's contribution to the taste report.
public struct BucketContribution: Sendable, Equatable {
    public var bucket: String
    /// S_d
    public var exposures: Int
    /// L_d
    public var likes: Int
    /// p_d (clamped to [0.001, 0.999])
    public var baseline: Double
    /// ℓ_d = clamp(ln(a_d / p_d), ±ln 3)
    public var lift: Double
    /// c_d = w_d · ℓ_d
    public var contribution: Double

    public init(bucket: String, exposures: Int, likes: Int, baseline: Double, lift: Double, contribution: Double) {
        self.bucket = bucket
        self.exposures = exposures
        self.likes = likes
        self.baseline = baseline
        self.lift = lift
        self.contribution = contribution
    }
}

/// The four display axes, each in −1…+1.
public struct TasteAxes: Sendable, Equatable, Codable {
    /// Old Masters (−) ↔ Modern (+)
    public var era: Double
    /// Figurative (−) ↔ Abstract (+)
    public var form: Double
    /// Earthy/Muted (−) ↔ Vivid/Luminous (+)
    public var palette: Double
    /// Serene (−) ↔ Dramatic (+)
    public var mood: Double

    public init(era: Double, form: Double, palette: Double, mood: Double) {
        self.era = era
        self.form = form
        self.palette = palette
        self.mood = mood
    }

    /// Archetype id from the axis signs (0 counts as +): era O/M, form F/A, palette E/V, mood S/D.
    /// E.g. `"OFES"` = old, figurative, earthy, serene.
    public var archetypeID: String {
        (era < 0 ? "O" : "M") + (form < 0 ? "F" : "A") + (palette < 0 ? "E" : "V") + (mood < 0 ? "S" : "D")
    }
}

/// Display-only taste analysis (Double math allowed).
public struct TasteReport: Sendable, Equatable {
    public var swipeCount: Int
    public var likeCount: Int
    /// DST = sqrt(mean of c_d² over buckets with S_d ≥ 1).
    public var distinctiveness: Double
    /// Sorted by |c_d| descending, then bucket key (UTF-8 order).
    public var contributions: [BucketContribution]
    public var axes: TasteAxes
    public var archetypeID: String { axes.archetypeID }

    public init(
        swipeCount: Int, likeCount: Int, distinctiveness: Double, contributions: [BucketContribution], axes: TasteAxes
    ) {
        self.swipeCount = swipeCount
        self.likeCount = likeCount
        self.distinctiveness = distinctiveness
        self.contributions = contributions
        self.axes = axes
    }
}

/// Computes the shrunk-lift taste model against a baseline.
public enum TasteAnalyzer {
    /// ln 3: lift clamp.
    public static let maxLift = DisplayMath.ln(3)
    public static let minBaseline = 0.001
    public static let maxBaseline = 0.999

    /// Axis loadings per bucket. Buckets not listed load 0 on every axis.
    public static let axisLoadings: [String: (axis: Int, load: Double)] = [
        "era:pre1500": (0, -1.0), "era:1500_1600": (0, -0.75), "era:1600_1700": (0, -0.5),
        "era:1700_1800": (0, -0.25), "era:1800_1850": (0, 0.25), "era:1850_1900": (0, 0.75),
        "era:1900_1930": (0, 1.0),
        "abstraction:low": (1, -1.0), "abstraction:high": (1, 1.0),
        "saturation:muted": (2, -1.0), "saturation:vivid": (2, 1.0),
        "brightness:dark": (2, -1.0), "brightness:light": (2, 1.0),
        "warmth:warm": (2, -0.5), "warmth:cool": (2, 0.5),
        "mood:serene": (3, -1.0), "mood:joyful": (3, -0.5), "mood:melancholic": (3, 0.5), "mood:dramatic": (3, 1.0),
    ]

    /// Analyzes a profile.
    ///
    /// For each bucket d with S_d ≥ 1 present in the baseline: a_d = (L_d + α·p_d)/(S_d + α);
    /// ℓ_d = clamp(ln(a_d/p_d), −ln3, ln3); w_d = S_d/(S_d + α); c_d = w_d·ℓ_d.
    /// Axis k = Σ load·c_d / (ln3 · Σ|load|) over its loaded buckets with S_d ≥ 1 (0 if none).
    public static func analyze(_ profile: TasteProfile, baseline: TasteBaseline) -> TasteReport {
        let alpha = baseline.alpha
        var contributions: [BucketContribution] = []
        for (bucket, s) in profile.exposures where s >= 1 {
            guard let base = baseline.features[bucket] else { continue }
            let p = min(max(base.pLike, minBaseline), maxBaseline)
            let l = Double(profile.likes[bucket] ?? 0)
            let sd = Double(s)
            let a = (l + alpha * p) / (sd + alpha)
            let lift = min(max(DisplayMath.ln(a / p), -maxLift), maxLift)
            let w = sd / (sd + alpha)
            contributions.append(
                BucketContribution(
                    bucket: bucket, exposures: s, likes: profile.likes[bucket] ?? 0, baseline: p, lift: lift,
                    contribution: w * lift))
        }
        contributions.sort {
            let a = abs($0.contribution)
            let b = abs($1.contribution)
            return a != b ? a > b : utf8Less($0.bucket, $1.bucket)
        }
        // Sum in bucket-key order so the result does not depend on dictionary order.
        let ordered = contributions.sorted { utf8Less($0.bucket, $1.bucket) }
        var sumSquares = 0.0
        var numerators = [0.0, 0.0, 0.0, 0.0]
        var weights = [0.0, 0.0, 0.0, 0.0]
        for c in ordered {
            sumSquares += c.contribution * c.contribution
            if let loading = axisLoadings[c.bucket] {
                numerators[loading.axis] += loading.load * c.contribution
                weights[loading.axis] += abs(loading.load)
            }
        }
        let dst = ordered.isEmpty ? 0 : (sumSquares / Double(ordered.count)).squareRoot()
        func axis(_ k: Int) -> Double {
            weights[k] == 0 ? 0 : min(max(numerators[k] / (maxLift * weights[k]), -1), 1)
        }
        return TasteReport(
            swipeCount: profile.swipeCount, likeCount: profile.likeCount, distinctiveness: dst,
            contributions: contributions, axes: TasteAxes(era: axis(0), form: axis(1), palette: axis(2), mood: axis(3)))
    }
}
