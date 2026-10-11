import ArtDesign
import ArtCore
import ArtData
import Testing
@testable import ArtPrice

@Suite("Daily challenge model")
struct DailyModelTests {
    let day = HomeContent.launchDay

    private func model(_ profile: ProfileModel, day: DayKey? = nil) throws -> DailyModel {
        try DailyModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: 0, day: day ?? self.day))
    }

    @Test("Five rounds, same for everyone, at least three kinds, intro before each round")
    func shape() throws {
        let (p1, _) = TestSupport.profile()
        let (p2, _) = TestSupport.profile()
        let a = try model(p1)
        let b = try model(p2)
        #expect(a.session.rounds == b.session.rounds)
        #expect(a.totalRounds == 5)
        #expect(Set(a.session.rounds.map(\.kind)).count >= 3)
        #expect(a.stage == .intro)
        #expect(a.introTitle.hasPrefix("Round 1 · "))
        #expect(a.answer(a.bestAnswer()!) == nil, "answers wait for the intro")
    }

    @Test("A perfect day scores 500, sets the streak and the share grid; a replay is practice")
    func resultAndPractice() async throws {
        let (profile, store) = TestSupport.profile()
        await profile.load()
        let first = try model(profile)
        #expect(!first.isPractice)
        first.playThrough { $0.bestAnswer() }
        #expect(first.isOver)
        #expect(first.total == 500)
        #expect(first.marks == Array(repeating: .hit, count: 5))
        #expect(first.shareText == "\(AppInfo.wordmark) · Day 1 · 500/500 ◆◆◆◆◆")
        #expect(first.streak == 1)
        #expect(profile.profile.daily.scores[day.isoString] == 500)

        let replay = try model(profile)
        #expect(replay.isPractice)
        replay.playThrough { Self.wrongAnswer($0.session.currentRound) }
        #expect(replay.isOver)
        #expect(profile.profile.daily.scores[day.isoString] == 500)
        #expect(profile.profile.daily.streak == 1)

        let tomorrow = try model(profile, day: day.adding(days: 1))
        #expect(!tomorrow.isPractice)
        tomorrow.playThrough { $0.bestAnswer() }
        #expect(tomorrow.streak == 2)

        await profile.drain()
        let log = await store.roundLog()
        #expect(log.records.count == 15)
        #expect(log.records.allSatisfy { $0.mode == .daily && $0.day != nil })
        #expect(await store.profile().daily.streak == 2)
    }

    /// An answer that misses (bid off the wall, wrong side / option).
    static func wrongAnswer(_ round: Round?) -> Answer? {
        switch round {
        case .bid(let r)?: .bid(position: r.actualMilli > 6000 ? 0 : 700)
        case .higherLower(let r)?: .higherLower(side: r.pricierSide == .top ? .bottom : .top)
        case .pickPrice(let r)?: .pickPrice(index: (r.correctIndex + 1) % 4)
        case .category(let r)?: .category(index: (r.correctIndex + 1) % 4)
        default: nil
        }
    }

    @Test("Bid marks: within 2× is ◆, within 10× is ◇, beyond is ▢")
    func marks() {
        #expect(DailyModel.glyph(.hit) == "◆")
        #expect(DailyModel.glyph(.close) == "◇")
        #expect(DailyModel.glyph(.miss) == "▢")
    }
}
