import ArtCore
import FixtureKit
import Testing

@Suite("Fixtures: taste, rarity, price format")
struct DisplayFixtureTests {
    @Test(arguments: try Fixtures.cases(TasteFixture.File.self, "taste.json"))
    func taste(_ c: FixtureCase<TasteFixture.Input, TasteFixture.Expected>) throws {
        var applied: [TasteSwipe] = []
        var profile = TasteProfile()
        for s in c.input.swipes {
            let artwork = try #require(Fixtures.pool.artwork(ArtworkID(s.artworkID)))
            let swipe = TasteSwipe(artwork: artwork, liked: s.liked)
            applied.append(swipe)
            profile = profile.applying(swipe)
        }
        for s in applied.suffix(c.input.undoLast).reversed() { profile = profile.undoing(s) }
        #expect(profile == c.expected.profile)
        let report = TasteAnalyzer.analyze(profile, baseline: Fixtures.mini.tasteBaseline)
        let tol = c.expected.tolerance
        #expect(abs(report.distinctiveness - c.expected.distinctiveness) <= tol)
        #expect(abs(report.axes.era - c.expected.axes.era) <= tol)
        #expect(abs(report.axes.form - c.expected.axes.form) <= tol)
        #expect(abs(report.axes.palette - c.expected.axes.palette) <= tol)
        #expect(abs(report.axes.mood - c.expected.axes.mood) <= tol)
        #expect(report.archetypeID == c.expected.archetypeID)
        #expect(report.contributions.prefix(3).map(\.bucket) == c.expected.topBuckets)
    }

    @Test(arguments: try Fixtures.cases(RarityFixture.File.self, "rarity.json"))
    func rarity(_ c: FixtureCase<RarityFixture.Input, RarityFixture.Expected>) {
        let r = RarityCalculator.rarity(
            dst: c.input.distinctiveness, swipeCount: c.input.swipeCount, archetypeID: c.input.archetypeID,
            baseline: Fixtures.mini.tasteBaseline)
        #expect(r.visibility == c.expected.visibility)
        #expect(r.swipeBucket == c.expected.swipeBucket)
        #expect(abs(r.percentile - c.expected.percentile) <= c.expected.tolerance)
        #expect(r.band == c.expected.band)
        #expect(r.archetypeShare == c.expected.archetypeShare)
        #expect(r.editionNumber == c.expected.editionNumber)
    }

    @Test(arguments: try Fixtures.cases(PriceFormatFixture.File.self, "price_format.json"))
    func priceFormat(_ c: FixtureCase<PriceFormatFixture.Input, PriceFormatFixture.Expected>) {
        #expect(SigFig.round2(c.input.usd) == c.expected.rounded)
        #expect(PriceFormatter.compactUSD(c.input.usd) == c.expected.compact)
        #expect(
            PriceFormatter.format(
                usd: c.input.usd, approximate: c.input.approximate, reported: c.input.reported,
                lowerBound: c.input.lowerBound) == c.expected.text)
    }
}
