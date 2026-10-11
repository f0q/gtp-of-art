import ArtCore
import FixtureKit

/// Builds every fixture file from the ArtCore implementation.
enum Generators {
    static let seeds: [UInt64] = [0, 1, 42, 1_234_567, 0xDEAD_BEEF, 0xFFFF_FFFF_FFFF_FFFF, fnv1a64("artprice")]

    static func prng() -> PRNGFixture.File {
        var cases: [FixtureCase<PRNGFixture.Input, PRNGFixture.Expected>] = []
        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let values = (0..<10).map { _ in FixtureIO.u64(rng.next()) }
            cases.append(.init(
                name: "next seed \(seed)", input: .init(seed: FixtureIO.u64(seed), count: 10, bound: nil),
                expected: .init(values: values, stateAfter: FixtureIO.u64(rng.state))))
        }
        // 2^62 + 1 rejects ~25% of draws, exercising the rejection loop.
        let bounds: [Int] = [1, 2, 3, 4, 6, 7, 10, 52, 1000, 4_611_686_018_427_387_905, Int.max]
        for bound in bounds {
            for seed in [UInt64(1_234_567), 0xDEAD_BEEF] {
                var rng = SplitMix64(seed: seed)
                let values = (0..<12).map { _ in String(rng.nextInt(bound)) }
                cases.append(.init(
                    name: "nextInt(\(bound)) seed \(seed)",
                    input: .init(seed: FixtureIO.u64(seed), count: 12, bound: String(bound)),
                    expected: .init(values: values, stateAfter: FixtureIO.u64(rng.state))))
            }
        }
        return .init(description: "SplitMix64 next() and nextInt(bound) streams. All 64-bit values are decimal strings.", cases: cases)
    }

    static func shuffleFixture() -> ShuffleFixture.File {
        var cases: [FixtureCase<ShuffleFixture.Input, ShuffleFixture.Expected>] = []
        for n in [0, 1, 2, 5, 10, 30] {
            for seed in [UInt64(1_234_567), 42, 0xFFFF_FFFF_FFFF_FFFF] {
                var rng = SplitMix64(seed: seed)
                var a = Array(0..<n)
                shuffle(&a, using: &rng)
                cases.append(.init(
                    name: "n=\(n) seed \(seed)", input: .init(seed: FixtureIO.u64(seed), n: n),
                    expected: .init(permutation: a, stateAfter: FixtureIO.u64(rng.state))))
            }
        }
        return .init(description: "Fisher–Yates shuffle of [0..n) with SplitMix64.", cases: cases)
    }

    static func fnv() -> FNVFixture.File {
        let texts = [
            "", "a", "foobar", "artprice",
            DailySeed.string(day: DayKey(year: 2026, month: 10, day: 11), datasetVersion: "mini-2026.10", dailyRulesVersion: 1),
            "Hokusai — 葛飾北斎", "Dürer",
        ]
        return .init(
            description: "FNV-1a 64 over UTF-8 bytes.",
            cases: texts.map { t in
                let h = fnv1a64(t)
                return .init(name: "fnv \"\(t)\"", input: .init(text: t), expected: .init(hash: FixtureIO.u64(h), hashHex: hex(h)))
            })
    }

    static func hex(_ v: UInt64) -> String {
        let digits = String(v, radix: 16)
        return "0x" + String(repeating: "0", count: 16 - digits.count) + digits
    }

    static func daykey() -> DayKeyFixture.File {
        let dates: [(Int, Int, Int)] = [
            (1970, 1, 1), (1969, 12, 31), (2000, 2, 29), (2000, 3, 1), (1900, 2, 28), (1900, 3, 1),
            (2024, 2, 29), (2026, 10, 11), (2026, 12, 31), (2027, 1, 1), (2028, 10, 10), (1, 1, 1), (9999, 12, 31),
            (2025, 2, 29), (1900, 2, 29), (2026, 13, 1), (2026, 4, 31), (2026, 0, 10),
        ]
        return .init(
            description: "DayKey validity, Hinnant days_from_civil (days since 1970-01-01) and yyyy-MM-dd formatting.",
            cases: dates.map { y, m, d in
                let key = DayKey(year: y, month: m, day: d)
                let valid = key.isValid
                return .init(
                    name: "\(y)-\(m)-\(d)", input: .init(year: y, month: m, day: d),
                    expected: .init(valid: valid, dayNumber: valid ? key.dayNumber : nil, iso: valid ? key.isoString : nil))
            })
    }

    static func streak() -> StreakFixture.File {
        let rows: [(String, Int, String?, String)] = [
            ("first completion", 0, nil, "2026-10-11"),
            ("next day", 4, "2026-10-10", "2026-10-11"),
            ("same day", 4, "2026-10-11", "2026-10-11"),
            ("travel backwards", 4, "2026-10-12", "2026-10-11"),
            ("missed one day", 4, "2026-10-09", "2026-10-11"),
            ("year boundary", 9, "2026-12-31", "2027-01-01"),
            ("leap day", 2, "2028-02-28", "2028-02-29"),
            ("non-leap month end", 2, "2027-02-28", "2027-03-01"),
            ("long gap", 30, "2025-10-11", "2026-10-11"),
        ]
        return .init(
            description: "Daily streak update: gap 1 → +1; gap ≤ 0 → unchanged; gap > 1 → 1; no previous → 1.",
            cases: rows.map { name, s, last, today in
                let u = Streak.update(streak: s, lastDay: last.flatMap(DayKey.init(string:)), today: DayKey(string: today)!)
                return .init(
                    name: name, input: .init(streak: s, lastDay: last, today: today),
                    expected: .init(streak: u.streak, lastDay: u.lastDay?.isoString))
            })
    }

    static func daily(_ mini: MiniDataset) throws -> DailyFixture.File {
        let pool = mini.pool
        let version = DailyChallenge.currentRulesVersion
        var cases: [FixtureCase<DailyFixture.Input, DailyFixture.Expected>] = []
        let start = DayKey(year: 2026, month: 10, day: 11)
        func add(_ name: String, _ day: DayKey, _ rules: Int) throws {
            let challenge = try DailyChallenge.make(dayKey: day, pool: pool, datasetVersion: mini.datasetID, dailyRulesVersion: rules)
            cases.append(.init(
                name: name, input: .init(day: day.isoString, datasetVersion: mini.datasetID, rulesVersion: rules),
                expected: .init(
                    seedString: DailySeed.string(day: day, datasetVersion: mini.datasetID, dailyRulesVersion: rules),
                    seed: FixtureIO.u64(challenge.seed), rounds: challenge.rounds)))
        }
        for offset in [0, 1, 2, 3, 50, 81, 365, 729] {
            let day = start.adding(days: offset)
            try add("daily \(day.isoString)", day, version)
        }
        try add("a different rules version changes the seed", start, version + 1)
        return .init(description: "Daily challenge over mini_dataset.json (rules version \(version)).", cases: cases)
    }

    static func distractors() -> DistractorFixture.File {
        let truths: [Int64] = [
            500, 850, 5_200, 28_000, 45_000, 250_000, 400_000, 1_000_000, 2_300_000, 5_544_000, 14_650_000,
            78_100_000, 110_747_000, 450_312_500, 999_999_999, 1_950_000_000, 2_000_000_000, 499, 2_100_000_000,
        ]
        var cases: [FixtureCase<DistractorFixture.Input, DistractorFixture.Expected>] = []
        for truth in truths {
            for difficulty in Difficulty.allCases {
                for seed in [UInt64(7), 1_234_567] {
                    var rng = SplitMix64(seed: seed)
                    let expected: DistractorFixture.Expected
                    do {
                        let o = try PriceOptionGenerator.make(truthUSD: truth, difficulty: difficulty, rng: &rng)
                        expected = .init(
                            options: o.options, correctIndex: o.correctIndex, usedFallback: o.usedFallback, error: nil,
                            stateAfter: FixtureIO.u64(rng.state))
                    } catch let error as GenerationError {
                        expected = .init(options: nil, correctIndex: nil, usedFallback: nil, error: error.code, stateAfter: FixtureIO.u64(rng.state))
                    } catch {
                        fatalError("\(error)")
                    }
                    cases.append(.init(
                        name: "$\(truth) \(difficulty.rawValue) seed \(seed)",
                        input: .init(truthUSD: truth, difficulty: difficulty, seed: FixtureIO.u64(seed)), expected: expected))
                }
            }
        }
        return .init(description: "Pick-the-price options (whole USD).", cases: cases)
    }

    static func bid() -> BidFixture.File {
        let rows: [(Int, Int)] = [
            (0, 2000), (700, 9000), (-5, 2000), (800, 9000), (465, 6653), (466, 6653), (475, 6653), (456, 6653),
            (455, 6653), (435, 6653), (435, 6352), (435, 6050), (435, 6049), (435, 5350), (435, 5349), (435, 5348),
            (500, 7903), (300, 8654), (600, 4362), (350, 5500),
        ]
        return .init(
            description: "Bid scoring: guessMilli = 2000 + 10·clamp(p,0,700); e = |guess − actual|; tiers ≤97/≤301/≤699/≤1000.",
            cases: rows.map { p, actual in
                let r = BidScorer.score(position: p, actualMilli: actual)
                return .init(
                    name: "p=\(p) actual=\(actual)", input: .init(position: p, actualMilli: actual),
                    expected: .init(
                        guessMilli: r.guessMilli, errorMilli: r.errorMilli, tier: r.tier, points: r.points,
                        direction: r.direction, factor: r.factor, factorTolerance: 1e-9))
            })
    }

    static func pairs(_ mini: MiniDataset) -> PairFixture.File {
        let pool = mini.pool
        var cases: [FixtureCase<PairFixture.Input, PairFixture.Expected>] = []
        func add(_ name: String, _ d: Difficulty, _ window: Int?, _ used: [String], _ anchor: String?, _ seed: UInt64) {
            var rng = SplitMix64(seed: seed)
            let expected: PairFixture.Expected
            do {
                let r = try PairSelector.select(
                    pool: pool, difficulty: d, yearWindow: window, used: Set(used.map(ArtworkID.init(_:))),
                    anchor: anchor.map(ArtworkID.init(_:)), rng: &rng)
                expected = .init(round: r, error: nil, stateAfter: FixtureIO.u64(rng.state))
            } catch let e as GenerationError {
                expected = .init(round: nil, error: e.code, stateAfter: FixtureIO.u64(rng.state))
            } catch { fatalError("\(error)") }
            cases.append(.init(
                name: name, input: .init(difficulty: d, yearWindow: window, used: used, anchor: anchor, seed: FixtureIO.u64(seed)),
                expected: expected))
        }
        for d in Difficulty.allCases {
            for seed in [UInt64(1), 2, 3, 1_234_567] {
                add("\(d.rawValue) no era seed \(seed)", d, nil, [], nil, seed)
                add("\(d.rawValue) era 60 seed \(seed)", d, 60, [], nil, seed)
            }
        }
        let allButThree = pool.artworks.map(\.id.rawValue).filter {
            !["monet-meules", "morisot-garden-study", "renoir-bal-du-moulin-small"].contains($0)
        }
        add("easy forced relaxation (3 impressionists left)", .easy, 60, allButThree, nil, 9)
        add("hard shared category among 3 left", .hard, nil, allButThree, nil, 9)
        func onlyKeep(_ keep: [String]) -> [String] { pool.artworks.map(\.id.rawValue).filter { !keep.contains($0) } }
        add("easy era relaxed (Leonardo vs Morisot)", .easy, 60, onlyKeep(["leonardo-salvator-mundi", "morisot-garden-study"]), nil, 21)
        add("easy relaxed to floor (Monet vs Kirchner)", .easy, 60, onlyKeep(["monet-meules", "kirchner-berlin-street-scene"]), nil, 22)
        add("hard shared category relaxed", .hard, nil, onlyKeep(["leonardo-salvator-mundi", "morisot-garden-study"]), nil, 23)
        add("below floor gap → exhausted", .hard, nil, onlyKeep(["monet-meules", "renoir-bal-du-moulin-small"]), nil, 24)
        add("anchored on Salvator Mundi", .medium, 60, [], "leonardo-salvator-mundi", 11)
        add("anchored on Hiroshige", .hard, nil, [], "hiroshige-sudden-shower", 12)
        add("pool exhausted", .easy, nil, Array(pool.artworks.map(\.id.rawValue).dropFirst()), nil, 13)
        add("invalid anchor", .easy, nil, [], "no-such-work", 14)
        return .init(description: "Which-is-pricier pair selection over mini_dataset.json (log10_usd_adjusted_milli).", cases: cases)
    }

    static func category(_ mini: MiniDataset) -> CategoryFixture.File {
        let pool = mini.pool
        var cases: [FixtureCase<CategoryFixture.Input, CategoryFixture.Expected>] = []
        let ids = [
            "monet-meules", "seurat-les-poseuses-small", "chardin-basket-wild-strawberries", "friedrich-moonrise-study", "durer-rhinoceros", "hokusai-under-the-wave", "rembrandt-aristotle",
            "leonardo-salvator-mundi", "munch-scream-pastel", "liotard-dutch-girl-breakfast", "turner-seascape-folkestone",
            "gauguin-nafea-faa-ipoipo",
        ]
        for id in ids {
            for d in Difficulty.allCases {
                for seed in [UInt64(5), 77] {
                    var rng = SplitMix64(seed: seed)
                    let expected: CategoryFixture.Expected
                    do {
                        let r = try CategoryQuestionGenerator.make(
                            artwork: pool.artwork(ArtworkID(id))!, pool: pool, difficulty: d, rng: &rng)
                        expected = .init(round: r, error: nil, stateAfter: FixtureIO.u64(rng.state))
                    } catch let e as GenerationError {
                        expected = .init(round: nil, error: e.code, stateAfter: FixtureIO.u64(rng.state))
                    } catch { fatalError("\(error)") }
                    cases.append(.init(
                        name: "\(id) \(d.rawValue) seed \(seed)", input: .init(artworkID: id, difficulty: d, seed: FixtureIO.u64(seed)),
                        expected: expected))
                }
            }
        }
        return .init(description: "Category quiz questions over mini_dataset.json.", cases: cases)
    }

    static func taste(_ mini: MiniDataset) -> TasteFixture.File {
        let pool = mini.pool
        let ids = pool.artworks.map(\.id.rawValue)
        func run(_ swipes: [TasteFixture.SwipeInput], undo: Int) -> TasteFixture.Expected {
            let applied = swipes.map { TasteSwipe(artwork: pool.artwork(ArtworkID($0.artworkID))!, liked: $0.liked) }
            var profile = TasteProfile()
            for s in applied { profile = profile.applying(s) }
            for s in applied.suffix(undo).reversed() { profile = profile.undoing(s) }
            let report = TasteAnalyzer.analyze(profile, baseline: mini.tasteBaseline)
            return .init(
                profile: profile, distinctiveness: report.distinctiveness, axes: report.axes, archetypeID: report.archetypeID,
                topBuckets: report.contributions.prefix(3).map(\.bucket), tolerance: 1e-9)
        }
        var cases: [FixtureCase<TasteFixture.Input, TasteFixture.Expected>] = []
        func add(_ name: String, _ swipes: [TasteFixture.SwipeInput], undo: Int = 0) {
            cases.append(.init(name: name, input: .init(swipes: swipes, undoLast: undo), expected: run(swipes, undo: undo)))
        }
        add("empty", [])
        add("one like", [.init(artworkID: "monet-meules", liked: true)])
        add("one pass", [.init(artworkID: "monet-meules", liked: false)])
        add("likes modern, passes old (all 30)", ids.map { id in
            .init(artworkID: id, liked: (pool.artwork(ArtworkID(id))!.year ?? 0) >= 1850)
        })
        add("likes old masters (all 30)", ids.map { id in
            .init(artworkID: id, liked: (pool.artwork(ArtworkID(id))!.year ?? 0) < 1700)
        })
        add("likes everything (all 30)", ids.map { .init(artworkID: $0, liked: true) })
        add("alternating 12", ids.prefix(12).enumerated().map { .init(artworkID: $1, liked: $0 % 2 == 0) })
        add("undo last 2 of 5", ids.prefix(5).map { .init(artworkID: $0, liked: true) }, undo: 2)
        add("likes dramatic moods", ids.map { id in
            .init(artworkID: id, liked: pool.artwork(ArtworkID(id))!.taste.mood == "dramatic")
        })
        return .init(description: "Taste model over mini_dataset.json and its taste_baseline. Doubles compare within `tolerance`.", cases: cases)
    }

    static func rarity(_ mini: MiniDataset) -> RarityFixture.File {
        let rows: [(Double, Int, String)] = [
            (0.10, 5, "OFES"), (0.10, 12, "OFES"), (0.0, 20, "MAVD"), (0.09, 15, "MFVS"), (0.18, 10, "OFED"),
            (0.21, 25, "MFES"), (0.27, 40, "OAVD"), (0.305, 60, "MAES"), (0.33, 80, "OFVS"), (0.45, 100, "MFVD"),
            (0.15, 30, "OAES"), (0.38, 59, "MAVS"), (0.2, 61, "ZZZZ"),
        ]
        return .init(
            description: "Rarity percentile (linear interpolation in the nearest swipe bucket's table), band and archetype share over mini_dataset.json's baseline. Percentile tolerance ±0.5.",
            cases: rows.map { dst, swipes, arch in
                let r = RarityCalculator.rarity(dst: dst, swipeCount: swipes, archetypeID: arch, baseline: mini.tasteBaseline)
                return .init(
                    name: "dst \(dst) swipes \(swipes) \(arch)", input: .init(distinctiveness: dst, swipeCount: swipes, archetypeID: arch),
                    expected: .init(
                        visibility: r.visibility, swipeBucket: r.swipeBucket, percentile: r.percentile, band: r.band,
                        archetypeShare: r.archetypeShare, editionNumber: r.editionNumber, tolerance: 0.5))
            })
    }

    static func priceFormat() -> PriceFormatFixture.File {
        let rows: [(Int64, Bool, Bool, Bool)] = [
            (0, false, false, false), (7, false, false, false), (99, false, false, false), (850, false, false, false),
            (949, false, false, false), (950, false, false, false), (999, false, false, false), (1_000, false, false, false),
            (1_049, false, false, false), (1_050, false, false, false), (5_200, false, false, false),
            (57_400, false, false, false), (99_500, false, false, false), (120_000, false, false, false),
            (999_499, false, false, false), (999_500, false, false, false), (2_760_000, false, false, false),
            (5_544_000, true, false, false), (450_312_500, false, false, false), (250_000_000, true, true, true),
            (184_000_000, true, true, false), (1_950_000_000, false, false, false), (1_000_000_000, false, false, true),
            (12_345_678_901, false, false, false),
        ]
        return .init(
            description: "2 significant figures (half up) + K/M/B; prefix ~ (reported) else ≈ (approximate); suffix + (lower bound).",
            cases: rows.map { usd, approx, reported, lower in
                .init(
                    name: "\(usd) a=\(approx) r=\(reported) lb=\(lower)",
                    input: .init(usd: usd, approximate: approx, reported: reported, lowerBound: lower),
                    expected: .init(
                        rounded: SigFig.round2(usd), compact: PriceFormatter.compactUSD(usd),
                        text: PriceFormatter.format(usd: usd, approximate: approx, reported: reported, lowerBound: lower)))
            })
    }

    static func weightedPick() -> WeightedPickFixture.File {
        let rows: [(String, [Int], UInt64, Int)] = [
            ("single", [5], 1, 3), ("uniform 4", [1, 1, 1, 1], 1_234_567, 12), ("3 vs 1", [3, 1], 42, 16),
            ("zeros skipped", [0, 2, 0, 1, 0], 7, 16), ("negative counts as zero", [-4, 1, 1], 9, 8),
            ("all zero", [0, 0, 0], 3, 5), ("empty", [], 3, 1), ("prior-like 3..9", [3, 5, 7, 9, 3, 5], 2026, 20),
            ("large", [1_000_000_007, 1, 999_999_999_999], 0xDEAD_BEEF, 10),
        ]
        return .init(
            description: "WeightedPicker: r = nextInt(Σ positive weights); first i with r < cumulative positive weight.",
            cases: rows.map { name, weights, seed, count in
                var rng = SplitMix64(seed: seed)
                var picks: [Int]? = []
                for _ in 0..<count {
                    guard let i = WeightedPicker.pick(weights: weights, rng: &rng) else { picks = nil; break }
                    picks?.append(i)
                }
                return .init(
                    name: name, input: .init(weights: weights, seed: FixtureIO.u64(seed), count: count),
                    expected: .init(picks: picks, stateAfter: FixtureIO.u64(rng.state)))
            })
    }

    static func prior(_ mini: MiniDataset) throws -> PriorFixture.File {
        let pool = mini.pool
        typealias A = OnboardingAnswers
        let rows: [(String, A, GameMode, [RoundSpec]?, UInt64)] = [
            ("skipped everything, swipe", A(), .swipe, nil, 1),
            ("classic era only, swipe", A(era: .classic), .swipe, nil, 2),
            ("modern + landscapes + serene, swipe", A(era: .modern, subjects: [.landscape], mood: .serene, intent: .play), .swipe, nil, 3),
            ("asian + prints, people, dramatic, pick price", A(era: .classic, departments: [.asianArt, .printsPhotographs], subjects: [.people], mood: .dramatic, intent: .testMyEye), .pickPrice, nil, 4),
            ("old masters, learn, category", A(era: .classic, departments: [.oldMasters], intent: .learn), .category, nil, 5),
            ("impressionist, higher-lower chained", A(era: .modern, departments: [.impressionistModern], intent: .play), .higherLower, nil, 6),
            ("old masters, higher-lower fixed hard", A(departments: [.oldMasters]), .higherLower, [RoundSpec(.higherLower, .hard)], 7),
            ("custom recipe bid x3 + pick hard", A(subjects: [.stillLife, .landscape], mood: .serene), .bid, [RoundSpec(.bid, .medium), RoundSpec(.bid, .medium), RoundSpec(.pickPrice, .hard), RoundSpec(.bid, .easy)], 8),
            ("daily ignores the prior", A(era: .classic, departments: [.oldMasters], subjects: [.people], mood: .dramatic), .daily, nil, 9),
        ]
        var cases: [FixtureCase<PriorFixture.Input, PriorFixture.Expected>] = []
        for (name, answers, mode, recipe, seed) in rows {
            let prior = TastePrior.from(answers: answers)
            let session = try GameSession.make(mode: mode, recipe: recipe, pool: pool, seed: seed, prior: prior)
            cases.append(.init(
                name: name, input: .init(answers: answers, mode: mode, recipe: recipe, seed: FixtureIO.u64(seed)),
                expected: .init(prior: prior, seededProfile: TasteProfile().seeded(from: prior), rounds: session.rounds)))
        }
        return .init(
            description: "Onboarding answers → TastePrior → seeded taste profile and prior-weighted session rounds over mini_dataset.json.",
            cases: cases)
    }
}
