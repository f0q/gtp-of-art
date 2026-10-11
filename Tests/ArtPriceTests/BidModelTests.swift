import ArtCore
import ArtData
import ArtDesign
import Testing
@testable import ArtPrice

@Suite("Bid model")
struct BidModelTests {
    @Test("Same seed, same rounds", arguments: TestSupport.seeds)
    func deterministic(seed: UInt64) throws {
        let (profile, _) = TestSupport.profile()
        let a = try BidModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: seed))
        let b = try BidModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: seed))
        #expect(a.session.rounds == b.session.rounds)
        #expect(a.totalRounds == 10)
    }

    @Test("Slider bounds are whole decades covering every price")
    func bounds() throws {
        #expect(BidModel.sliderBounds([4_100, 8_900]) == 200...700)
        #expect(BidModel.sliderBounds([6_000, 6_500]) == 400...500)
        #expect(BidModel.sliderBounds([]) == 200...700)
        let (profile, _) = TestSupport.profile()
        let model = try BidModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: 1))
        for round in model.session.rounds {
            guard case .bid(let r) = round else { continue }
            let position = (r.actualMilli - 2000) / 10
            #expect(model.bounds.contains(position))
            #expect(model.bounds.lowerBound % 100 == 0 && model.bounds.upperBound % 100 == 0)
        }
    }

    @Test("Exact bids are bullseyes; a ~9× miss is in the room; records persist")
    func scoring() async throws {
        let (profile, store) = TestSupport.profile()
        let model = try BidModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: 5))
        let first = try #require(model.round)
        model.position = BidScorer.position(forMilli: first.actualMilli)
        let hit = try #require(model.placeBid())
        #expect(hit.bidTier == .bullseye)
        #expect(hit.points == 100)
        #expect(model.result?.direction != nil)
        model.advance()
        #expect(model.position == (model.bounds.lowerBound + model.bounds.upperBound) / 2)

        let second = try #require(model.round)
        model.position = BidScorer.position(forMilli: second.actualMilli - 950)
        let low = try #require(model.placeBid())
        #expect(low.bidTier == .inTheRoom)
        #expect(model.result?.direction == .under)
        #expect(PriceCopy.bidRatio(try #require(model.result)).hasSuffix("× under."))
        model.advance()

        await profile.drain()
        #expect(await store.roundLog().records.count == 2)
        #expect(profile.stats(.bid).totalPoints == 115)
    }

    @Test("Finishing ten bids records the session and builds the summary")
    func finish() async throws {
        let (profile, _) = TestSupport.profile()
        let model = try BidModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: 9))
        while let round = model.round, !model.isOver {
            model.position = BidScorer.position(forMilli: round.actualMilli)
            model.placeBid()
            model.advance()
        }
        #expect(model.isOver)
        #expect(model.session.totalPoints == 1000)
        let summary = model.summary()
        #expect(summary.headline == "Average miss 1.0×")
        #expect(summary.marks.count == 10)
        #expect(profile.stats(.bid).sessionsCompleted == 1)
    }
}
