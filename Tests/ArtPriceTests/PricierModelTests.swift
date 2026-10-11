import ArtDesign
import ArtCore
import ArtData
import Testing
@testable import ArtPrice

@Suite("Which is pricier model")
struct PricierModelTests {
    @Test("Same seed, same chain", arguments: TestSupport.seeds)
    func deterministic(seed: UInt64) throws {
        let (profile, _) = TestSupport.profile()
        let a = try PricierModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: seed))
        let b = try PricierModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: seed))
        #expect(a.session.rounds == b.session.rounds)
        #expect(!a.session.rounds.isEmpty)
    }

    @Test("Correct answers extend the streak; one miss ends the run and sets the personal best")
    func run() async throws {
        let (profile, store) = TestSupport.profile()
        let model = try PricierModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: 21))
        for expected in 1...12 {
            let round = try #require(model.round)
            let outcome = try #require(model.choose(round.pricierSide))
            #expect(outcome.isCorrect == true)
            #expect(model.streak == expected)
            model.advance()
            #expect(!model.isOver)
        }
        let round = try #require(model.round)
        let miss = try #require(model.choose(round.pricierSide == .top ? .bottom : .top))
        #expect(miss.isCorrect == false)
        #expect(model.session.isFinished)
        model.advance()
        #expect(model.isOver)
        #expect(model.isPersonalBest)
        #expect(model.summary().headline == "Streak 12")

        await profile.drain()
        #expect(await store.roundLog().records.count == 13)
        let stats = await store.profile().stats[.higherLower]
        #expect(stats?.bestStreak == 12)
        #expect(stats?.sessionsCompleted == 1)

        // The next run starts from the persisted best.
        let next = try PricierModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: 22))
        #expect(next.previousBest == 12)
    }

    @Test("Quitting mid-run records the run once")
    func quit() throws {
        let (profile, _) = TestSupport.profile()
        let model = try PricierModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: 4))
        let round = try #require(model.round)
        model.choose(round.pricierSide)
        model.advance()
        model.quit()
        model.quit()
        #expect(profile.stats(.higherLower).sessionsCompleted == 1)
        #expect(profile.stats(.higherLower).bestStreak == 1)
    }

    @Test("Quitting before answering records nothing")
    func quitEarly() throws {
        let (profile, _) = TestSupport.profile()
        let model = try PricierModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: 4))
        model.quit()
        #expect(profile.stats(.higherLower) == ModeStats())
    }
}
