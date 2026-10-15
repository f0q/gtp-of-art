import ArtCore
import Foundation
import Testing

@testable import ArtData

@Suite("Sessions and daily")
struct SessionTests {
    let real = TestSupport.dataset
    /// The real works with `min_quiz_items = 6`, so category rounds (and the daily) generate.
    let quizReady = TestSupport.dataset(minQuizItems: 6)

    static let standaloneModes: [GameMode] = [.pickPrice, .higherLower, .category, .bid, .swipe]

    @Test(arguments: standaloneModes)
    func sameSeedSameRounds(mode: GameMode) throws {
        let a = try SessionFactory.make(mode: mode, dataset: quizReady, seed: 42)
        let b = try SessionFactory.make(mode: mode, dataset: quizReady, seed: 42)
        let c = try SessionFactory.make(mode: mode, dataset: quizReady, seed: 43)
        #expect(a == b)
        #expect(a.rounds != c.rounds)
        let expectedCount = GameSession.recipe(for: mode)?.count ?? GameSession.batchSize
        #expect(a.rounds.count == expectedCount)
        #expect(Set(a.used).count == a.used.count)
    }

    @Test(arguments: [GameMode.pickPrice, .higherLower, .bid, .swipe])
    func realDataBuildsPriceModes(mode: GameMode) throws {
        #expect(try SessionFactory.make(mode: mode, dataset: real, seed: 7).rounds.isEmpty == false)
    }

    @Test func realDataBuildsCategorySessions() {
        let probe = GeneratorProbe.probeSessions(mode: .category, pool: real.pool, attempts: 50)
        #expect(probe.successes == 50, "category session failures: \(probe.failures)")
        #expect(probe.roundsPerSession == 10)
    }

    @Test func rejectsDaily() {
        #expect(throws: SessionFactoryError.dailyNotStandalone) {
            try SessionFactory.make(mode: .daily, dataset: real, seed: 1)
        }
    }

    @Test func endlessExtendsInBatchesAndChains() throws {
        var session = try SessionFactory.make(mode: .higherLower, dataset: real, seed: 2026)
        #expect(SessionFactory.extendIfNeeded(&session, dataset: real) == 0)  // 10 pending: not needed
        while session.rounds.count < 25, case .higherLower(let pair)? = session.currentRound {
            session.submit(.higherLower(side: pair.pricierSide))
            SessionFactory.extendIfNeeded(&session, dataset: real)
        }
        #expect(session.rounds.count >= 20)
        #expect(session.rounds.count % GameSession.batchSize == 0)
        for i in 1..<session.rounds.count {
            guard case .higherLower(let prev) = session.rounds[i - 1], case .higherLower(let next) = session.rounds[i]
            else { continue }
            #expect(next.top == prev.pricier)  // higher-or-lower chaining
        }
        // Replaying with the same seed and answers reproduces the same rounds.
        var replay = try SessionFactory.make(mode: .higherLower, dataset: real, seed: 2026)
        while replay.rounds.count < session.rounds.count, case .higherLower(let pair)? = replay.currentRound {
            replay.submit(.higherLower(side: pair.pricierSide))
            SessionFactory.extendIfNeeded(&replay, dataset: real)
        }
        #expect(Array(replay.rounds.prefix(session.rounds.count)) == session.rounds)
    }

    @Test func dailyIsIdempotentWithinADay() throws {
        let provider = FixedDayProvider(dayKey: DayKey(year: 2026, month: 10, day: 11))
        let first = try DailyService.today(provider: provider, dataset: quizReady)
        let second = try DailyService.today(provider: provider, dataset: quizReady)
        #expect(first == second)
        #expect(first.session.rounds.map(\.kind) == DailyChallenge.recipe.map(\.kind))
        #expect(first.seed == DailySeed.seed(
            day: provider.dayKey, datasetVersion: quizReady.datasetVersion,
            dailyRulesVersion: DailyChallenge.currentRulesVersion))
        let tomorrow = try DailyService.today(
            provider: FixedDayProvider(dayKey: provider.dayKey.adding(days: 1)), dataset: quizReady)
        #expect(tomorrow.session.rounds != first.session.rounds)
    }

    @Test func dailyBuildsOnRealData() throws {
        let start = DayKey(year: 2026, month: 10, day: 12)
        let report = DailyValidator.check(real.pool, from: start, days: 730, datasetVersion: real.datasetVersion)
        #expect(report.daysChecked == 730)
        #expect(report.failures.isEmpty, "first failures: \(report.failures.prefix(3))")
        let today = try DailyService.today(provider: FixedDayProvider(dayKey: start), dataset: real)
        #expect(today.session.rounds.map(\.kind) == DailyChallenge.recipe.map(\.kind))
    }

    @Test func streakBookkeeping() throws {
        let day1 = DayKey(year: 2026, month: 10, day: 11)
        var profile = PlayerProfile(localPlayerID: "p")
        #expect(DailyService.status(on: day1, profile: profile).displayedStreak == 0)

        func finished(_ day: DayKey) throws -> GameSession {
            var session = try DailyService.challenge(for: day, dataset: quizReady).session
            while let round = session.currentRound {
                session.submit(ScriptedPlayer.answer(for: round, index: 0))  // always correct
            }
            return session
        }
        let s1 = try finished(day1)
        #expect(DailyService.recordCompletion(of: try DailyService.challenge(for: day1, dataset: quizReady).session,
            on: day1, in: profile) == profile)  // unfinished: no change
        profile = DailyService.recordCompletion(of: s1, on: day1, in: profile)
        var status = DailyService.status(on: day1, profile: profile)
        #expect(status.isCompleted && status.score == 500 && status.displayedStreak == 1)

        // Replaying the same day is practice.
        #expect(DailyService.recordCompletion(of: s1, on: day1, in: profile) == profile)

        let day2 = day1.adding(days: 1)
        profile = DailyService.recordCompletion(of: try finished(day2), on: day2, in: profile)
        #expect(DailyService.status(on: day2, profile: profile).displayedStreak == 2)

        // Skipping a day: displayed streak drops to 0, next completion restarts at 1.
        let day4 = day1.adding(days: 3)
        #expect(DailyService.status(on: day4, profile: profile).displayedStreak == 0)
        profile = DailyService.recordCompletion(of: try finished(day4), on: day4, in: profile)
        status = DailyService.status(on: day4, profile: profile)
        #expect(status.displayedStreak == 1 && status.bestStreak == 2)
    }
}

@Suite("Custom difficulty and onboarding prior")
struct PriorSessionTests {
    let real = TestSupport.dataset
    let modernPrior = TastePrior.from(answers: OnboardingAnswers(departments: [.impressionistModern]))

    @Test(arguments: [GameMode.pickPrice, .category, .bid], Difficulty.allCases)
    func fixedModesPlayTenRoundsAtTheDifficulty(mode: GameMode, difficulty: Difficulty) throws {
        let a = try SessionFactory.make(mode: mode, difficulty: difficulty, dataset: real, seed: 11)
        #expect(a.rounds.count == 10)
        #expect(a == (try SessionFactory.make(mode: mode, difficulty: difficulty, dataset: real, seed: 11)))
        for round in a.rounds {
            switch round {
            case .pickPrice(let r): #expect(r.difficulty == difficulty)
            case .category(let r): #expect(r.difficulty == difficulty)
            default: break
            }
        }
    }

    @Test func higherLowerRampStartsAtTheDifficulty() throws {
        for (difficulty, first) in [(Difficulty.easy, Difficulty.easy), (.medium, .medium), (.hard, .hard)] {
            let s = try SessionFactory.make(mode: .higherLower, difficulty: difficulty, dataset: real, seed: 3)
            guard case .higherLower(let r) = s.rounds[0] else { Issue.record("not a pair"); continue }
            #expect(r.difficulty == first)
        }
        #expect(SessionFactory.recipe(for: .higherLower, difficulty: .medium)?.count == 11)
        #expect(SessionFactory.recipe(for: .swipe, difficulty: .hard)?.count == 20)
        #expect(SessionFactory.recipe(for: .bid, difficulty: nil) == nil)
    }

    @Test func priorIsPassedThrough() throws {
        let s = try SessionFactory.make(mode: .swipe, dataset: real, seed: 9, prior: modernPrior)
        #expect(s.prior == modernPrior)
        #expect(try SessionFactory.make(mode: .swipe, dataset: real, seed: 9).prior == nil)
    }

    /// Over 40 seeds, swipe and pick-the-price sessions with a modern prior show clearly more
    /// impressionist & modern works than without one. A department-only prior weighs a preferred
    /// work 5 vs 3 (spec §17A.3), so the expected lift is relative (~1.4× at most), not a fixed
    /// number of points; with seven departments in v1 the absolute lift for pick-the-price is ~+0.05.
    @Test(arguments: [GameMode.swipe, .pickPrice])
    func priorFavoursThePreferredDepartment(mode: GameMode) throws {
        func share(_ prior: TastePrior?) throws -> Double {
            var hits = 0
            var total = 0
            for seed in 0..<40 {
                let s = try SessionFactory.make(mode: mode, dataset: real, seed: UInt64(1000 + seed), prior: prior)
                for id in s.rounds.flatMap(\.artworkIDs) {
                    total += 1
                    if real.department(of: id) == .impressionistModern { hits += 1 }
                }
            }
            return Double(hits) / Double(total)
        }
        let base = try share(nil)
        let biased = try share(modernPrior)
        print("\(mode.rawValue): impressionist_modern share \(base) → \(biased) with prior")
        #expect(biased > base * 1.15)
    }

    @Test func priorPrefersSameDepartmentPairs() throws {
        func sameDepartmentShare(_ prior: TastePrior?) throws -> Double {
            var same = 0
            var total = 0
            for seed in 0..<40 {
                let s = try SessionFactory.make(mode: .higherLower, dataset: real, seed: UInt64(seed), prior: prior)
                for case .higherLower(let r) in s.rounds {
                    total += 1
                    if real.department(of: r.top) == .impressionistModern
                        && real.department(of: r.bottom) == .impressionistModern
                    {
                        same += 1
                    }
                }
            }
            return Double(same) / Double(total)
        }
        let base = try sameDepartmentShare(nil)
        let biased = try sameDepartmentShare(modernPrior)
        print("higher_lower: both-impressionist_modern pairs \(base) → \(biased) with prior")
        #expect(biased > base + 0.1)
    }

    @Test func dailyIgnoresThePrior() throws {
        let provider = FixedDayProvider(dayKey: DayKey(year: 2026, month: 10, day: 12))
        var profile = PlayerProfile(localPlayerID: "p")
        profile = OnboardingService.complete(
            answers: OnboardingAnswers(departments: [.asianArt], mood: .dramatic), profile: profile, dataset: real)
        #expect(profile.prior != nil)
        let plain = try DailyService.today(provider: provider, dataset: real)
        let withProfile = try DailyService.today(provider: provider, dataset: real, profile: profile)
        #expect(withProfile.challenge == plain)
        #expect(withProfile.challenge.session.prior == nil)
        let direct = try GameSession.make(
            mode: .daily, recipe: nil, pool: real.pool, seed: plain.seed, prior: profile.prior)
        #expect(direct.rounds == plain.session.rounds)
    }
}
