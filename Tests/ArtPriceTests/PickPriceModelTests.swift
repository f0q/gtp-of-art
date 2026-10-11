import ArtDesign
import ArtCore
import ArtData
import Testing
@testable import ArtPrice

@Suite("Pick the price model")
struct PickPriceModelTests {
    @Test("Same seed, same rounds", arguments: TestSupport.seeds)
    func deterministic(seed: UInt64) throws {
        let (profile, _) = TestSupport.profile()
        let a = try PickPriceModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: seed))
        let b = try PickPriceModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: seed))
        #expect(a.session.rounds == b.session.rounds)
        #expect(a.totalRounds == 10)
        for round in a.session.rounds {
            guard case .pickPrice(let r) = round else { Issue.record("wrong kind"); continue }
            #expect(r.options == r.options.sorted())
            #expect(r.options.count == 4)
        }
    }

    @Test("All correct: streak bonus from the third answer; records and stats persisted")
    func perfectRun() async throws {
        let (profile, store) = TestSupport.profile()
        let model = try PickPriceModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: 7))
        var points: [Int] = []
        while let round = model.round, !model.isOver {
            let outcome = try #require(model.choose(round.correctIndex))
            points.append(outcome.points)
            #expect(model.isRevealing)
            #expect(model.choose(0) == nil, "input is locked during the reveal")
            model.advance()
        }
        #expect(points == [100, 100] + Array(repeating: 125, count: 8))
        #expect(model.session.totalPoints == 1200)
        #expect(model.isOver)
        #expect(model.summary().headline == "10/10")

        await profile.drain()
        let log = await store.roundLog()
        #expect(log.records.count == 10)
        #expect(log.records.map(\.roundIndex) == Array(0..<10))
        #expect(log.records.allSatisfy { $0.mode == .pickPrice && $0.sessionSeed == 7 })
        let stats = await store.profile().stats[.pickPrice]
        #expect(stats?.roundsPlayed == 10)
        #expect(stats?.roundsCorrect == 10)
        #expect(stats?.sessionsCompleted == 1)
        #expect(stats?.bestStreak == 10)
        #expect(stats?.bestSessionPoints == 1200)
    }

    @Test("A miss resets the streak and the bonus")
    func missResetsStreak() throws {
        let (profile, _) = TestSupport.profile()
        let model = try PickPriceModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: 11))
        func answer(correct: Bool) throws -> RoundOutcome {
            let round = try #require(model.round)
            let index = correct ? round.correctIndex : (round.correctIndex + 1) % 4
            let outcome = try #require(model.choose(index))
            model.advance()
            return outcome
        }
        #expect(try answer(correct: true).points == 100)
        #expect(try answer(correct: true).points == 100)
        #expect(try answer(correct: true).points == 125)
        #expect(try answer(correct: false).points == 0)
        #expect(model.session.streak == 0)
        #expect(try answer(correct: true).points == 100)
        #expect(model.play.longestStreak == 3)
        #expect(profile.stats(.pickPrice).roundsPlayed == 5)
        #expect(profile.stats(.pickPrice).sessionsCompleted == 0)
    }

    @Test("Upcoming artwork is the next round's work")
    func upcoming() throws {
        let (profile, _) = TestSupport.profile()
        let model = try PickPriceModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: 3))
        let next = model.session.rounds[1].artworkIDs
        #expect(model.upcomingArtworks.map(\.id) == next)
    }
}
