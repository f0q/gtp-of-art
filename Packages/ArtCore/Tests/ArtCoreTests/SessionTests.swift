import ArtCore
import FixtureKit
import Foundation
import Testing

@Suite("Sessions, scoring and persistence")
struct SessionTests {
    let pool = Fixtures.pool

    @Test(arguments: [GameMode.pickPrice, .category, .bid, .swipe, .daily])
    func fixedSessions(mode: GameMode) throws {
        var session = try GameSession.make(mode: mode, pool: pool, seed: 77)
        let expectedCount = GameSession.recipe(for: mode)!.count
        #expect(session.rounds.count == expectedCount)
        #expect(Set(session.used).count == session.used.count)
        #expect(try GameSession.make(mode: mode, pool: pool, seed: 77) == session)
        while let round = session.currentRound {
            session.submit(Self.correctAnswer(for: round))
        }
        #expect(session.isFinished)
        #expect(session.outcomes.count == expectedCount)
        #expect(session.submit(.swipe(liked: true)) == nil)
        if mode == .pickPrice {
            // 100, 100, then 125 from the third correct answer onwards.
            #expect(session.outcomes.map(\.points) == [100, 100] + Array(repeating: 125, count: 8))
        }
        if mode == .daily { #expect(session.totalPoints == 500) }
    }

    @Test func higherLowerEndlessAndChained() throws {
        var session = try GameSession.make(mode: .higherLower, pool: pool, seed: 5)
        #expect(session.isEndless)
        #expect(session.rounds.count <= GameSession.batchSize)
        var answered = 0
        while let round = session.currentRound {
            if case .higherLower(let r) = round, answered > 0, case .higherLower(let previous) = session.rounds[answered - 1] {
                #expect(r.top == previous.pricier)
            }
            session.submit(Self.correctAnswer(for: round))
            answered += 1
            if session.needsMoreRounds { try session.appendBatch(pool: pool) }
        }
        // 30 works: the run ends when the pool is exhausted, never with a repeated challenger.
        #expect(session.isFinished)
        #expect(session.outcomes.allSatisfy { $0.isCorrect == true })
        #expect(Set(session.used).count == session.used.count)
    }

    @Test func higherLowerEndsOnMiss() throws {
        var session = try GameSession.make(mode: .higherLower, pool: pool, seed: 6)
        guard case .higherLower(let r)? = session.currentRound else { Issue.record("no round"); return }
        let outcome = session.submit(.higherLower(side: r.pricierSide == .top ? .bottom : .top))
        #expect(outcome?.isCorrect == false)
        #expect(session.isFinished)
    }

    @Test func scorerIsTotal() throws {
        let session = try GameSession.make(mode: .daily, pool: pool, seed: 1)
        let answers: [Answer] = [
            .pickPrice(index: 9), .pickPrice(index: -1), .higherLower(side: .top), .category(index: 4), .bid(position: 9999),
            .swipe(liked: false),
        ]
        for round in session.rounds {
            for answer in answers {
                let o = Scorer.score(round, answer)
                #expect(o.points >= 0 && o.points <= 125)
                if answer.kind != round.kind { #expect(o == .invalid) }
            }
        }
    }

    @Test func categoryAlternateCountsAsCorrect() {
        let round = Round.category(
            CategoryRound(artwork: "x", options: ["a", "b", "c", "d"], correctIndex: 0, accepted: ["c"], difficulty: .easy))
        #expect(Scorer.score(round, .category(index: 0)).categoryMatch == .correct)
        let alt = Scorer.score(round, .category(index: 2))
        #expect(alt.categoryMatch == .alternate && alt.isCorrect == true && alt.points == 100)
        #expect(Scorer.score(round, .category(index: 1)).categoryMatch == .incorrect)
    }

    @Test func codableRoundTrips() throws {
        var profile = PlayerProfile(localPlayerID: "00000000-0000-0000-0000-000000000001")
        profile.stats[.pickPrice] = ModeStats().recording(RoundOutcome(isCorrect: true, points: 125))
        profile.daily = profile.daily.completing(DayKey(year: 2026, month: 10, day: 11), score: 410)
        profile.taste = profile.taste.applying(TasteSwipe(artwork: pool.artworks[0], liked: true))
        let data = try JSONEncoder().encode(profile)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let stats = try #require(json["stats"] as? [String: Any], "enum-keyed dictionary must encode as an object")
        #expect(stats["pick_price"] != nil)
        #expect((json["daily"] as? [String: Any])?["last_completed_day"] as? String == "2026-10-11")
        #expect(try JSONDecoder().decode(PlayerProfile.self, from: data) == profile)

        var session = try GameSession.make(mode: .daily, pool: pool, seed: 3)
        session.submit(.pickPrice(index: 0))
        let decoded = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(session))
        #expect(decoded == session)
        let record = RoundRecord(
            mode: .daily, sessionSeed: session.seed, roundIndex: 0, round: session.rounds[0], answer: session.answers[0],
            outcome: session.outcomes[0], day: DayKey(year: 2026, month: 10, day: 11), playedAt: 1_791_000_000)
        #expect(try JSONDecoder().decode(RoundRecord.self, from: JSONEncoder().encode(record)) == record)
    }

    @Test func dailyStateStreaks() {
        let d = DayKey(year: 2026, month: 10, day: 11)
        var s = DailyState()
        s = s.completing(d, score: 300)
        s = s.completing(d, score: 500)  // replay = practice
        #expect(s.streak == 1 && s.scores[d.isoString] == 300)
        s = s.completing(d.adding(days: 1), score: 400)
        #expect(s.streak == 2 && s.bestStreak == 2)
        #expect(s.displayedStreak(today: d.adding(days: 2)) == 2)
        #expect(s.displayedStreak(today: d.adding(days: 3)) == 0)
        s = s.completing(d.adding(days: 5), score: 100)
        #expect(s.streak == 1 && s.bestStreak == 2)
    }

    @Test func priceRecordFormatting() throws {
        let cezanne = try #require(pool.artwork("cezanne-card-players")?.gamePrice)
        #expect(PriceFormatter.format(cezanne, basis: .nominal) == "~$250M+")
        let velazquez = try #require(pool.artwork("velazquez-juan-de-pareja")?.gamePrice)
        #expect(PriceFormatter.format(velazquez, basis: .nominal) == "≈$5.5M")
        let monet = try #require(pool.artwork("monet-meules")?.gamePrice)
        #expect(PriceFormatter.format(monet, basis: .nominal) == "$110M")
        #expect(PriceFormatter.qualifier(for: .auctionHammer, premiumIncluded: false) == "hammer")
    }

    @Test func miniDatasetIsConsistent() {
        #expect(Fixtures.mini.artworks.count == 30)
        for a in Fixtures.mini.artworks {
            guard let p = a.gamePrice else { Issue.record("\(a.id) has no game price"); continue }
            #expect(p.log10UsdNominalMilli == Int((1000 * log10(Double(p.usdNominal))).rounded()))
            #expect(p.log10UsdAdjustedMilli == Int((1000 * log10(Double(p.usdAdjusted))).rounded()))
            #expect(p.usdNominal >= 5_000 && p.usdNominal <= 450_312_500)
            #expect(pool.category(a.category) != nil)
            #expect(a.taste.eraBucket == TasteFeatures.eraBucket(forYear: a.year!))
        }
        // Rococo (2 works, min 3) is active but not quiz-eligible; it may still be a distractor.
        #expect(pool.quizCategoryIDs.count == 12)
        #expect(pool.activeCategoryIDs.count == 13)
        #expect(!pool.quizCategoryIDs.contains("rococo") && pool.activeCategoryIDs.contains("rococo"))
    }

    @Test func catalogDecodesDisclaimerAndRefYear() throws {
        // The mini dataset uses the same top-level keys as dataset.json.
        let mini = try Data(contentsOf: Fixtures.directory.appendingPathComponent(MiniDataset.fileName))
        let catalog = try JSONDecoder().decode(ArtworkCatalog.self, from: mini)
        #expect(catalog.datasetID == "mini-2026.10")
        #expect(catalog.artworks.count == 30)
        #expect(catalog.refYear == 2025)
        #expect(catalog.disclaimer?.hasPrefix("Fixture prices are approximate") == true)
        #expect(catalog.refYear == Fixtures.mini.refYear && catalog.disclaimer == Fixtures.mini.disclaimer)
        // Older files without the keys still decode.
        let old = try JSONDecoder().decode(
            ArtworkCatalog.self, from: Data(#"{"schema_version":1,"dataset_id":"x","artworks":[]}"#.utf8))
        #expect(old.disclaimer == nil && old.refYear == nil)
        #expect(try JSONDecoder().decode(ArtworkCatalog.self, from: JSONEncoder().encode(catalog)) == catalog)
    }

    @Test func imagePaletteDecodes() throws {
        for a in Fixtures.mini.artworks {
            let palette = try #require(a.image.palette)
            #expect(palette.count == 5)
            #expect(palette.first == a.image.dominantHex)
            #expect(palette.allSatisfy { $0.count == 7 && $0.hasPrefix("#") })
        }
        let json = ##"{"licence":"CC0","attribution":"x","alt_text":"y","focus":{"x":1,"y":2},"dominant_hex":"#000000"}"##
        #expect(try JSONDecoder().decode(ImageRef.self, from: Data(json.utf8)).palette == nil)
    }

    @Test func displayResultInitialisers() {
        let c = BucketContribution(bucket: "mood:serene", exposures: 3, likes: 2, baseline: 0.5, lift: 0.2, contribution: 0.1)
        var r = Rarity(
            visibility: .exact, swipeBucket: 40, percentile: 80, band: RarityBand(lower: 75, upper: 90), archetypeID: "OFES",
            archetypeShare: 0.07, editionNumber: 7)
        r.percentile = 91
        #expect(r.percentile == 91 && c.bucket == "mood:serene")
        let report = TasteReport(
            swipeCount: 1, likeCount: 1, distinctiveness: 0.1, contributions: [c], axes: TasteAxes(era: -1, form: -1, palette: -1, mood: -1))
        #expect(report.archetypeID == "OFES")
        #expect(BidScorer.score(position: 465, actualMilli: 6653)
            == BidResult(position: 465, guessMilli: 6650, actualMilli: 6653, errorMilli: 3, tier: .bullseye, points: 100, direction: .under))
        #expect(PriceOptions(options: [1, 2, 3, 4], correctIndex: 0, usedFallback: false).correctIndex == 0)
        #expect(Streak.Update(streak: 1, lastDay: nil).streak == 1)
        #expect(DailyValidator.Report(daysChecked: 1, failures: [.init(day: DayKey(year: 2026, month: 1, day: 1), reason: "x")]).isValid == false)
    }

    static func correctAnswer(for round: Round) -> Answer {
        switch round {
        case .pickPrice(let r): .pickPrice(index: r.correctIndex)
        case .higherLower(let r): .higherLower(side: r.pricierSide)
        case .category(let r): .category(index: r.correctIndex)
        case .bid(let r): .bid(position: BidScorer.position(forMilli: r.actualMilli))
        case .swipe: .swipe(liked: true)
        }
    }
}
