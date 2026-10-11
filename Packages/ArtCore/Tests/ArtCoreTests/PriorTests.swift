import ArtCore
import FixtureKit
import Foundation
import Testing

@Suite("Onboarding prior, departments and weighted sampling")
struct PriorTests {
    let pool = Fixtures.pool

    @Test(arguments: try Fixtures.cases(WeightedPickFixture.File.self, "weighted_pick.json"))
    func weightedPick(_ c: FixtureCase<WeightedPickFixture.Input, WeightedPickFixture.Expected>) {
        var rng = SplitMix64(seed: u64(c.input.seed))
        var picks: [Int]? = []
        for _ in 0..<c.input.count {
            guard let i = WeightedPicker.pick(weights: c.input.weights, rng: &rng) else {
                picks = nil
                break
            }
            picks?.append(i)
        }
        #expect(picks == c.expected.picks)
        #expect(rng.state == u64(c.expected.stateAfter))
    }

    @Test(arguments: try Fixtures.cases(PriorFixture.File.self, "prior.json"))
    func priorFixture(_ c: FixtureCase<PriorFixture.Input, PriorFixture.Expected>) throws {
        let prior = TastePrior.from(answers: c.input.answers)
        #expect(prior == c.expected.prior)
        #expect(TasteProfile().seeded(from: prior) == c.expected.seededProfile)
        let session = try GameSession.make(
            mode: c.input.mode, recipe: c.input.recipe, pool: pool, seed: u64(c.input.seed), prior: prior)
        #expect(session.rounds == c.expected.rounds)
    }

    @Test("Weights are respected within tolerance over 10,000 picks; zero weights never picked")
    func weightsRespected() {
        let weights = [0, 1, 3, 9, 0, 27, 2]
        let total = weights.reduce(0, +)
        var counts = [Int](repeating: 0, count: weights.count)
        var rng = SplitMix64(seed: 77)
        let n = 10_000
        for _ in 0..<n { counts[WeightedPicker.pick(weights: weights, rng: &rng)!] += 1 }
        for (i, w) in weights.enumerated() {
            if w == 0 {
                #expect(counts[i] == 0)
            } else {
                let expected = Double(n * w) / Double(total)
                let sd = (expected * (1 - Double(w) / Double(total))).squareRoot()
                #expect(abs(Double(counts[i]) - expected) <= 5 * sd, "index \(i): \(counts[i]) vs \(expected)")
            }
        }
        var r2 = SplitMix64(seed: 1)
        #expect(WeightedPicker.pick(weights: [0, 0], rng: &r2) == nil)
        #expect(r2 == SplitMix64(seed: 1), "a zero total consumes no draw")
        #expect(WeightedPicker.pick(weights: [], rng: &r2) == nil)
    }

    @Test("Zero-weight entries are never picked, for random weight vectors")
    func zeroNeverPicked() {
        var rng = SplitMix64(seed: 2024)
        for _ in 0..<2000 {
            let weights = (0..<(1 + rng.nextInt(8))).map { _ in rng.nextInt(3) == 0 ? 0 : rng.nextInt(30) }
            guard let i = WeightedPicker.pick(weights: weights, rng: &rng) else {
                #expect(weights.allSatisfy { $0 <= 0 })
                continue
            }
            #expect(weights[i] > 0)
        }
    }

    @Test("Prior biases swipe sessions toward preferred departments")
    func priorBiasesSampling() throws {
        let prior = TastePrior.from(answers: OnboardingAnswers(departments: [.oldMasters]))
        var preferredFirst = 0
        var unweightedFirst = 0
        let oldMasters = Set(pool.artworkIDs(in: .oldMasters))
        for seed in 0..<2000 {
            let a = try GameSession.make(mode: .swipe, recipe: [RoundSpec(.swipe, .medium)], pool: pool, seed: UInt64(seed), prior: prior)
            let b = try GameSession.make(mode: .swipe, recipe: [RoundSpec(.swipe, .medium)], pool: pool, seed: UInt64(seed))
            if oldMasters.contains(a.rounds[0].artworkIDs[0]) { preferredFirst += 1 }
            if oldMasters.contains(b.rounds[0].artworkIDs[0]) { unweightedFirst += 1 }
        }
        // 11 of 30 works are Old Masters, weight 3+1+1 = 5 vs 3: share 11·5/(11·5+19·3) = 49.1% vs 36.7%.
        #expect(abs(Double(preferredFirst) / 2000 - 55.0 / 112) < 0.04)
        #expect(abs(Double(unweightedFirst) / 2000 - 11.0 / 30) < 0.04)
    }

    @Test("Prior pairs: department passes yield same preferred department; gap always met")
    func priorPairs() throws {
        let prior = TastePrior.from(answers: OnboardingAnswers(era: .modern))
        for difficulty in Difficulty.allCases {
            let passes = PairSelector.passes(difficulty: difficulty, yearWindow: 60, preferredDepartments: prior.preferredDepartments)
            for seed in 0..<200 {
                var rng = SplitMix64(seed: UInt64(seed))
                let r = try PairSelector.select(pool: pool, difficulty: difficulty, yearWindow: 60, used: [], prior: prior, rng: &rng)
                let pass = passes[r.relaxation]
                let top = try #require(pool.artwork(r.top))
                let bottom = try #require(pool.artwork(r.bottom))
                #expect(PairSelector.accepts(top, bottom, pass, pool: pool))
                #expect(abs(r.topMilli - r.bottomMilli) >= 301)
                if pass.departments != nil {
                    #expect(pool.department(of: top) == .impressionistModern && pool.department(of: bottom) == .impressionistModern)
                }
            }
        }
        // Without a preference the passes are unchanged.
        #expect(PairSelector.passes(difficulty: .hard, yearWindow: nil, preferredDepartments: []) == PairSelector.passes(difficulty: .hard, yearWindow: nil))
    }

    @Test("Daily ignores the prior")
    func dailyIgnoresPrior() throws {
        let prior = TastePrior.from(answers: OnboardingAnswers(era: .classic, subjects: [.people], mood: .dramatic))
        let plain = try GameSession.make(mode: .daily, pool: pool, seed: 99)
        let withPrior = try GameSession.make(mode: .daily, recipe: [RoundSpec(.bid, .hard)], pool: pool, seed: 99, prior: prior)
        #expect(plain.rounds == withPrior.rounds)
        #expect(withPrior.prior == nil)
    }

    @Test("TastePrior.from maps answers")
    func priorMapping() {
        let p = TastePrior.from(answers: OnboardingAnswers(era: .classic, subjects: [.people], mood: .serene, intent: .learn))
        #expect(p.departmentWeights == [.oldMasters: 3, .nineteenthCentury: 3])
        #expect(p.subjectWeights == ["portrait": 3, "figure": 3, "genre": 3])
        #expect(p.moodWeights == ["serene": 3, "joyful": 3])
        #expect(p.defaultDifficulty == .easy && p.highlightedMode == .category)
        #expect(p.weight(forDepartment: .asianArt) == 1 && p.weight(forDepartment: nil) == 1)
        let explicit = TastePrior.from(answers: OnboardingAnswers(era: .classic, departments: [.asianArt], intent: .testMyEye))
        #expect(explicit.departmentWeights == [.asianArt: 3], "step 2 overrides the era's departments")
        #expect(explicit.defaultDifficulty == .hard && explicit.highlightedMode == .bid)
        #expect(explicit.seedBuckets.isEmpty, "Asian art is era-neutral")
        for a in pool.artworks {
            let w = p.weight(for: a, in: pool)
            #expect(w >= 3 && w <= 9)
        }
    }

    @Test("Seeds: S=L=2 per bucket, re-seeding replaces, undo never removes seeds")
    func seeds() throws {
        let prior = TastePrior.from(answers: OnboardingAnswers(era: .modern, subjects: [.landscape], mood: .serene))
        let seeded = TasteProfile().seeded(from: prior)
        for b in prior.seedBuckets {
            #expect(seeded.exposures[b] == 2 && seeded.likes[b] == 2 && seeded.seeds[b] == 2)
        }
        #expect(seeded.swipeCount == 0)
        let monet = try #require(pool.artwork("monet-meules"))
        let swipe = TasteSwipe(artwork: monet, liked: true)
        let swiped = seeded.applying(swipe)
        #expect(swiped.undoing(swipe) == seeded)
        // An unmatched undo cannot eat into the seed.
        #expect(seeded.undoing(swipe) == seeded)
        // Re-seeding with another prior removes the old seed and keeps real swipes.
        let other = TastePrior.from(answers: OnboardingAnswers(era: .classic))
        let reseeded = swiped.seeded(from: other)
        #expect(reseeded == TasteProfile().applying(swipe).seeded(from: other))
        #expect(TasteProfile().seeded(from: other).seeded(from: TastePrior.from(answers: OnboardingAnswers())) == TasteProfile())
        // Round trip with seeds.
        #expect(try JSONDecoder().decode(TasteProfile.self, from: JSONEncoder().encode(swiped)) == swiped)
    }

    @Test("Every era-bearing department has typical era buckets")
    func departmentEraBuckets() {
        for d in [DepartmentID.oldMasters, .nineteenthCentury, .impressionistModern] {
            #expect((Department.typicalEraBuckets[d] ?? []).count >= 1, "\(d)")
            for b in Department.typicalEraBuckets[d] ?? [] {
                #expect(["pre1500", "1500_1600", "1600_1700", "1700_1800", "1800_1850", "1850_1900", "1900_1930"].contains(b))
            }
        }
        #expect(Department.typicalEraBuckets[.asianArt] == [])
        #expect(Department.typicalEraBuckets[.printsPhotographs] == [])
        for d in Fixtures.mini.departments where d.id != .asianArt && d.id != .printsPhotographs {
            #expect((Department.typicalEraBuckets[d.id] ?? []).count >= 1, "\(d.id)")
        }
    }

    @Test("Departments resolve via category, explicit id, or department listing")
    func departments() throws {
        #expect(pool.departments.map(\.id) == [.asianArt, .impressionistModern, .nineteenthCentury, .oldMasters, .printsPhotographs])
        #expect(pool.artworkIDs(in: .oldMasters).count == 11)
        #expect(pool.artworkIDs(in: .impressionistModern).count == 13)
        let total = pool.departments.map { pool.artworkIDs(in: $0.id).count }.reduce(0, +)
        #expect(total == 30)
        var hokusai = try #require(pool.artwork("hokusai-under-the-wave"))
        #expect(pool.department(of: hokusai) == .asianArt)
        hokusai.departmentID = .printsPhotographs
        let categoriesWithoutIDs = Fixtures.mini.taxonomy.map { c -> ArtCore.Category in
            var c = c
            c.departmentID = nil
            return c
        }
        let p2 = GamePool(artworks: [hokusai], categories: categoriesWithoutIDs, departments: Fixtures.mini.departments)
        #expect(p2.department(of: hokusai) == .printsPhotographs, "explicit artwork department wins")
        let p3 = GamePool(artworks: Fixtures.mini.artworks, categories: categoriesWithoutIDs, departments: Fixtures.mini.departments)
        #expect(p3.department(of: "monet-meules") == .impressionistModern, "falls back to the department listing")

        let json = #"{"categories": [], "departments": [{"id": "asian_art", "label": "Asian Art", "categories": ["ukiyo_e"]}]}"#
        let taxonomy = try JSONDecoder().decode(Taxonomy.self, from: Data(json.utf8))
        #expect(taxonomy.departments.first?.categories == ["ukiyo_e"])
        #expect(try JSONDecoder().decode(Taxonomy.self, from: Data(#"{"categories": []}"#.utf8)).departments.isEmpty)
    }

    @Test("Custom recipes and higher-lower difficulty override")
    func customRecipe() throws {
        let recipe = [RoundSpec(.pickPrice, .hard), RoundSpec(.category, .easy)]
        var s = try GameSession.make(mode: .pickPrice, recipe: recipe, pool: pool, seed: 4)
        #expect(s.rounds.map(\.kind) == [.pickPrice, .category])
        #expect(try GameSession.make(mode: .pickPrice, recipe: [], pool: pool, seed: 4) == GameSession.make(mode: .pickPrice, pool: pool, seed: 4))
        s.submit(.pickPrice(index: 0))
        s.submit(.category(index: 0))
        #expect(s.isFinished)
        let hl = try GameSession.make(mode: .higherLower, recipe: [RoundSpec(.higherLower, .hard)], pool: pool, seed: 4)
        for r in hl.rounds {
            guard case .higherLower(let p) = r else { Issue.record("kind"); continue }
            #expect(p.difficulty == .hard)
        }
        let decoded = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(hl))
        #expect(decoded == hl)
    }

    @Test("GenerationError descriptions and profile prior persistence")
    func errorsAndProfile() throws {
        #expect(GenerationError.poolExhausted(.higherLower).description == "pool_exhausted(higher_lower)")
        #expect("\(GenerationError.noQuizCategory("x"))" == "no_quiz_category(x)")
        let prior = TastePrior.from(answers: OnboardingAnswers(era: .modern, intent: .play))
        let profile = PlayerProfile(hasOnboarded: true, localPlayerID: "id", prior: prior)
        let data = try JSONEncoder().encode(profile)
        #expect(try JSONDecoder().decode(PlayerProfile.self, from: data) == profile)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let weights = try #require((json["prior"] as? [String: Any])?["department_weights"] as? [String: Int])
        #expect(weights == ["impressionist_modern": 3])
        // Older profile.json without `prior` still decodes.
        let old = #"{"schema_version":1,"has_onboarded":false,"stats":{},"taste":{"swipe_count":0,"like_count":0,"exposures":{},"likes":{}},"daily":{"streak":0,"best_streak":0,"scores":{}},"seen_tips":[],"local_player_id":"x"}"#
        #expect(try JSONDecoder().decode(PlayerProfile.self, from: Data(old.utf8)).prior == nil)
    }
}
