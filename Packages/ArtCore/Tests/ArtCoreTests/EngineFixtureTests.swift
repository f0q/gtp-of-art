import ArtCore
import FixtureKit
import Testing

@Suite("Fixtures: engines")
struct EngineFixtureTests {
    @Test(arguments: try Fixtures.cases(DistractorFixture.File.self, "distractors.json"))
    func distractors(_ c: FixtureCase<DistractorFixture.Input, DistractorFixture.Expected>) {
        var rng = SplitMix64(seed: u64(c.input.seed))
        var result: PriceOptions?
        let code = errorCode {
            result = try PriceOptionGenerator.make(truthUSD: c.input.truthUSD, difficulty: c.input.difficulty, rng: &rng)
        }
        #expect(code == c.expected.error)
        #expect(result?.options == c.expected.options)
        #expect(result?.correctIndex == c.expected.correctIndex)
        #expect(result?.usedFallback == c.expected.usedFallback)
        #expect(rng.state == u64(c.expected.stateAfter))
    }

    @Test(arguments: try Fixtures.cases(BidFixture.File.self, "bid_score.json"))
    func bid(_ c: FixtureCase<BidFixture.Input, BidFixture.Expected>) {
        let r = BidScorer.score(position: c.input.position, actualMilli: c.input.actualMilli)
        #expect(r.guessMilli == c.expected.guessMilli)
        #expect(r.errorMilli == c.expected.errorMilli)
        #expect(r.tier == c.expected.tier)
        #expect(r.points == c.expected.points)
        #expect(r.direction == c.expected.direction)
        #expect(abs(r.factor - c.expected.factor) <= c.expected.factorTolerance * c.expected.factor)
    }

    @Test(arguments: try Fixtures.cases(PairFixture.File.self, "pairs.json"))
    func pairs(_ c: FixtureCase<PairFixture.Input, PairFixture.Expected>) {
        var rng = SplitMix64(seed: u64(c.input.seed))
        var round: HigherLowerRound?
        let code = errorCode {
            round = try PairSelector.select(
                pool: Fixtures.pool, difficulty: c.input.difficulty, yearWindow: c.input.yearWindow,
                used: Set(c.input.used.map(ArtworkID.init(_:))), anchor: c.input.anchor.map(ArtworkID.init(_:)), rng: &rng)
        }
        #expect(code == c.expected.error)
        #expect(round == c.expected.round)
        #expect(rng.state == u64(c.expected.stateAfter))
    }

    @Test(arguments: try Fixtures.cases(CategoryFixture.File.self, "category.json"))
    func category(_ c: FixtureCase<CategoryFixture.Input, CategoryFixture.Expected>) throws {
        let artwork = try #require(Fixtures.pool.artwork(ArtworkID(c.input.artworkID)))
        var rng = SplitMix64(seed: u64(c.input.seed))
        var round: CategoryRound?
        let code = errorCode {
            round = try CategoryQuestionGenerator.make(artwork: artwork, pool: Fixtures.pool, difficulty: c.input.difficulty, rng: &rng)
        }
        #expect(code == c.expected.error)
        #expect(round == c.expected.round)
        #expect(rng.state == u64(c.expected.stateAfter))
    }

    @Test(arguments: try Fixtures.cases(DailyFixture.File.self, "daily.json"))
    func daily(_ c: FixtureCase<DailyFixture.Input, DailyFixture.Expected>) throws {
        let day = try #require(DayKey(string: c.input.day))
        #expect(DailySeed.string(day: day, datasetVersion: c.input.datasetVersion, dailyRulesVersion: c.input.rulesVersion) == c.expected.seedString)
        let challenge = try DailyChallenge.make(
            dayKey: day, pool: Fixtures.pool, datasetVersion: c.input.datasetVersion, dailyRulesVersion: c.input.rulesVersion)
        #expect(challenge.seed == u64(c.expected.seed))
        #expect(challenge.rounds == c.expected.rounds)
    }
}
