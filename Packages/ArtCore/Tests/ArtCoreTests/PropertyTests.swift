import ArtCore
import FixtureKit
import Foundation
import Testing

@Suite("Properties")
struct PropertyTests {
    @Test("Distractor constraints hold for 2,000 random prices and seeds per difficulty")
    func distractorConstraints() throws {
        var meta = SplitMix64(seed: 2026)
        for difficulty in Difficulty.allCases {
            for _ in 0..<2000 {
                // Log-uniform truth across the whole $500…$2B band.
                let milli = 2699 + meta.nextInt(9301 - 2699 + 1)
                let truth = Int64(pow(10, Double(milli) / 1000).rounded())
                guard SigFig.round2(truth) <= PriceOptionGenerator.maxUSD, SigFig.round2(truth) >= PriceOptionGenerator.minUSD
                else { continue }
                var rng = SplitMix64(seed: meta.next())
                let o = try PriceOptionGenerator.make(truthUSD: truth, difficulty: difficulty, rng: &rng)
                #expect(o.options.count == 4)
                #expect(o.options[o.correctIndex] == SigFig.round2(truth))
                #expect(PriceOptionGenerator.isValid(o.options, correctIndex: o.correctIndex))
                for (i, v) in o.options.enumerated() {
                    #expect(SigFig.round2(v) == v)
                    if i != o.correctIndex { #expect(v != 1_000_000 && v != 1_000_000_000) }
                    if i > 0 { #expect(o.options[i - 1] * 18 <= v * 10) }
                }
            }
        }
    }

    @Test("Truth slot is roughly uniform for mid-band prices")
    func truthSlotUniform() throws {
        var counts = [0, 0, 0, 0]
        var meta = SplitMix64(seed: 11)
        for _ in 0..<4000 {
            // $100K…$10M: far from the band edges, so every slot is usually feasible.
            let truth = Int64(pow(10, 5 + Double(meta.nextInt(2001)) / 1000).rounded())
            var rng = SplitMix64(seed: meta.next())
            counts[try PriceOptionGenerator.make(truthUSD: truth, difficulty: .medium, rng: &rng).correctIndex] += 1
        }
        for c in counts { #expect(c > 850 && c < 1150) }
    }

    @Test("Pair selector never returns a pair below the gap of the pass it reports")
    func pairGap() throws {
        let pool = Fixtures.pool
        for difficulty in Difficulty.allCases {
            for seed in 0..<300 {
                var rng = SplitMix64(seed: UInt64(seed))
                let window: Int? = seed % 2 == 0 ? 60 : nil
                let r = try PairSelector.select(pool: pool, difficulty: difficulty, yearWindow: window, used: [], rng: &rng)
                let pass = PairSelector.passes(difficulty: difficulty, yearWindow: window)[r.relaxation]
                #expect(abs(r.topMilli - r.bottomMilli) >= pass.minGapMilli)
                #expect(abs(r.topMilli - r.bottomMilli) >= 301)
                #expect(r.top != r.bottom)
                let top = try #require(pool.artwork(r.top))
                let bottom = try #require(pool.artwork(r.bottom))
                #expect(PairSelector.accepts(top, bottom, pass))
                #expect(r.pricier == (top.gamePrice!.log10UsdAdjustedMilli > bottom.gamePrice!.log10UsdAdjustedMilli ? r.top : r.bottom))
            }
        }
    }

    @Test("Category questions follow the distractor rules")
    func categoryRules() throws {
        let pool = Fixtures.pool
        for artwork in pool.artworks where CategoryQuestionGenerator.truthCategory(for: artwork, pool: pool) != nil {
            for difficulty in Difficulty.allCases {
                for seed in 0..<20 {
                    var rng = SplitMix64(seed: UInt64(seed))
                    let q = try CategoryQuestionGenerator.make(artwork: artwork, pool: pool, difficulty: difficulty, rng: &rng)
                    #expect(Set(q.options).count == 4)
                    let truth = try #require(pool.category(q.options[q.correctIndex]))
                    #expect(pool.quizCategoryIDs.contains(truth.id))
                    for (i, id) in q.options.enumerated() where i != q.correctIndex {
                        let c = try #require(pool.category(id))
                        #expect(pool.activeCategoryIDs.contains(id))
                        #expect(!artwork.allCategories.contains(id))
                        if truth.axis == .movement { #expect(c.axis == .movement) }
                        if difficulty != .hard { #expect(c.parent != truth.id && truth.parent != c.id) }
                    }
                }
            }
        }
    }

    @Test("Daily validator passes 730 days on the mini dataset")
    func dailyValidator() {
        let report = DailyValidator.check(
            Fixtures.pool, from: DayKey(year: 2026, month: 10, day: 11), days: 730, datasetVersion: Fixtures.mini.datasetID)
        #expect(report.daysChecked == 730)
        #expect(report.failures.isEmpty, "\(report.failures.prefix(3))")
    }

    @Test("Daily challenge is deterministic and changes day to day")
    func dailyDeterminism() throws {
        let day = DayKey(year: 2026, month: 10, day: 11)
        let a = try DailyChallenge.make(dayKey: day, pool: Fixtures.pool, datasetVersion: "mini-2026.10")
        let b = try DailyChallenge.make(dayKey: day, pool: Fixtures.pool, datasetVersion: "mini-2026.10")
        let c = try DailyChallenge.make(dayKey: day.adding(days: 1), pool: Fixtures.pool, datasetVersion: "mini-2026.10")
        #expect(a == b)
        #expect(a.rounds != c.rounds)
        // Input order of the dataset must not matter.
        let reversed = GamePool(artworks: Fixtures.mini.artworks.reversed(), categories: Fixtures.mini.taxonomy.reversed())
        #expect(try DailyChallenge.make(dayKey: day, pool: reversed, datasetVersion: "mini-2026.10") == a)
    }

    @Test("Undo exactly inverts taste updates")
    func undoInverts() throws {
        var rng = SplitMix64(seed: 99)
        let works = Fixtures.pool.artworks
        var profile = TasteProfile()
        var history: [TasteProfile] = [profile]
        var swipes: [TasteSwipe] = []
        for _ in 0..<200 {
            let swipe = TasteSwipe(artwork: works[rng.nextInt(works.count)], liked: rng.nextInt(2) == 0)
            profile = profile.applying(swipe)
            swipes.append(swipe)
            history.append(profile)
            #expect(profile.undoing(swipe) == history[history.count - 2])
        }
        for swipe in swipes.reversed() {
            history.removeLast()
            profile = profile.undoing(swipe)
            #expect(profile == history.last)
        }
        #expect(profile == TasteProfile())
    }

    @Test("Taste axes and distinctiveness stay in range")
    func tasteRanges() {
        var rng = SplitMix64(seed: 5)
        let works = Fixtures.pool.artworks
        var profile = TasteProfile()
        for _ in 0..<500 {
            profile = profile.applying(TasteSwipe(artwork: works[rng.nextInt(works.count)], liked: rng.nextInt(3) == 0))
            let r = TasteAnalyzer.analyze(profile, baseline: Fixtures.mini.tasteBaseline)
            for v in [r.axes.era, r.axes.form, r.axes.palette, r.axes.mood] { #expect(v >= -1 && v <= 1) }
            #expect(r.distinctiveness >= 0 && r.distinctiveness <= log(3))
            let rarity = RarityCalculator.rarity(for: r, baseline: Fixtures.mini.tasteBaseline)
            #expect(rarity.percentile >= 0 && rarity.percentile <= 99)
        }
    }

    @Test("Display math matches Foundation")
    func displayMath() {
        var rng = SplitMix64(seed: 1)
        for _ in 0..<5000 {
            let x = Double(rng.next() >> 11) / Double(1 << 53) * 40 + 1e-9
            #expect(abs(DisplayMath.ln(x) - log(x)) <= 1e-14 * max(1, abs(log(x))))
            let y = Double(rng.nextInt(20_001) - 10_000) / 1000
            #expect(abs(DisplayMath.exp(y) - exp(y)) <= 1e-13 * exp(y))
            #expect(abs(DisplayMath.pow10(y) - pow(10, y)) <= 1e-13 * pow(10, y))
        }
        #expect(DisplayMath.ln(1) == 0)
        #expect(DisplayMath.exp(0) == 1)
    }

    @Test("nextInt stays in range and is unbiased for small bounds")
    func nextIntDistribution() {
        var rng = SplitMix64(seed: 3)
        var counts = [Int](repeating: 0, count: 7)
        for _ in 0..<70_000 {
            let v = rng.nextInt(7)
            counts[v] += 1
        }
        for c in counts { #expect(c > 9_500 && c < 10_500) }
    }

    @Test("Bid tier boundaries")
    func bidBoundaries() {
        #expect(BidScorer.tier(errorMilli: 0) == .bullseye)
        #expect(BidScorer.tier(errorMilli: 97) == .bullseye)
        #expect(BidScorer.tier(errorMilli: 98) == .expertEye)
        #expect(BidScorer.tier(errorMilli: 301) == .expertEye)
        #expect(BidScorer.tier(errorMilli: 302) == .goodInstinct)
        #expect(BidScorer.tier(errorMilli: 699) == .goodInstinct)
        #expect(BidScorer.tier(errorMilli: 700) == .inTheRoom)
        #expect(BidScorer.tier(errorMilli: 1000) == .inTheRoom)
        #expect(BidScorer.tier(errorMilli: 1001) == .offTheWall)
        for p in 0...700 { #expect(BidScorer.position(forMilli: BidScorer.guessMilli(position: p)) == p) }
        #expect(BidScorer.displayUSD(position: 0) == 100)
        #expect(BidScorer.displayUSD(position: 700) == 1_000_000_000)
    }

    @Test("ArtCore sources never import Foundation")
    func noFoundation() throws {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        dir.appendPathComponent("Sources/ArtCore")
        let files = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)!
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(files.count > 20)
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for banned in ["import Foundation", "import Darwin", "import Glibc", "shuffled(using:", "random(in:"] {
                #expect(!text.contains(banned), "\(file.lastPathComponent) contains \(banned)")
            }
        }
    }
}
