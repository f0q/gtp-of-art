import ArtDesign
import ArtCore
import ArtData
import Testing
@testable import ArtPrice

@Suite("Onboarding → prior → sessions")
struct OnboardingTests {
    private func choice(_ model: OnboardingModel, _ id: String) throws -> OnboardingChoice {
        try #require(model.choices.first { $0.id == id })
    }

    @Test("Classic branch offers Old Masters, 19th Century, Asian Art and Prints & Multiples; answers become a prior")
    func flow() async throws {
        let (profile, store) = TestSupport.profile()
        await profile.load()
        let model = OnboardingModel(dataset: TestSupport.dataset, profile: profile)
        #expect(model.step == 1)
        model.choose(try choice(model, "classic"))
        #expect(model.step == 2)
        #expect(model.choices.map(\.id) == ["old_masters", "nineteenth_century", "asian_art", "prints_multiples"])
        #expect(!model.canContinue)
        model.choose(try choice(model, "asian_art"))
        model.choose(try choice(model, "prints_multiples"))
        model.continueFromDepartments()
        #expect(model.step == 3)
        model.choose(try choice(model, "subject:landscape"))
        model.choose(try choice(model, "mood:serene"))
        #expect(model.step == 5)
        model.choose(.learn)
        #expect(model.isComplete)

        let prior = try #require(profile.profile.prior)
        #expect(profile.profile.hasOnboarded)
        #expect(prior.highlightedMode == .category)
        #expect(prior.defaultDifficulty == .easy)
        #expect(prior.departmentWeights == [.asianArt: TastePrior.preferredWeight, .printsMultiples: TastePrior.preferredWeight])
        #expect(!prior.seedBuckets.contains { $0.hasPrefix("era:") }, "both picks are era-neutral")
        await profile.drain()
        #expect(await store.profile().prior == prior)
        #expect(await store.profile().hasOnboarded)
    }

    @Test("Modern branch splits Impressionist and Avant-garde and adds Vintage Posters and Photographs")
    func modernBranch() throws {
        let (profile, _) = TestSupport.profile()
        let model = OnboardingModel(dataset: TestSupport.dataset, profile: profile)
        model.choose(try choice(model, "modern"))
        #expect(model.choices.map(\.id) == [
            "impressionist_modern:impressionist", "impressionist_modern:avant_garde", "posters", "photographs",
        ])
        model.choose(try choice(model, "impressionist_modern:impressionist"))
        model.choose(try choice(model, "impressionist_modern:avant_garde"))
        #expect(model.answers.departments == [.impressionistModern])
        model.choose(try choice(model, "posters"))
        model.choose(try choice(model, "photographs"))
        #expect(model.answers.departments == [.impressionistModern, .posters, .photographs])
        model.choose(try choice(model, "posters"))
        #expect(model.answers.departments == [.impressionistModern, .photographs], "tapping again deselects")
    }

    @Test("Every step-2 tile id is a department in the taxonomy; at most 4 tiles per branch")
    func departmentTiles() {
        let known = Set(TestSupport.dataset.departments.map(\.id))
        for era in OnboardingAnswers.Era.allCases {
            let ids = OnboardingModel.departmentChoiceIDs(for: era)
            #expect(ids.count <= 4)
            for id in ids {
                let choice = TestSupport.dataset.onboarding.choice(id)
                #expect(choice?.step == 2, "\(id) missing from onboarding.json")
                #expect(choice?.department.map(known.contains) == true, "\(id) is not a taxonomy department")
            }
        }
    }

    @Test("Skip finishes with no prior; redo clears the flag")
    func skipAndReset() throws {
        let (profile, _) = TestSupport.profile()
        let model = OnboardingModel(dataset: TestSupport.dataset, profile: profile)
        model.skip()
        #expect(profile.profile.hasOnboarded)
        #expect(profile.profile.prior == nil)
        profile.resetOnboarding()
        #expect(!profile.profile.hasOnboarded)
    }

    @Test("Exemplars resolve to bundled artworks for every choice")
    func exemplars() {
        let (profile, _) = TestSupport.profile()
        let model = OnboardingModel(dataset: TestSupport.dataset, profile: profile)
        for c in TestSupport.dataset.onboarding.choices where c.step <= 4 {
            #expect(model.exemplar(for: c) != nil, "no exemplar for \(c.id)")
        }
    }

    @Test("A department prior biases Pick-the-price sessions toward that department")
    func bias() throws {
        let dataset = TestSupport.dataset
        let prior = try #require(OnboardingService.prior(
            for: OnboardingAnswers(departments: [.impressionistModern]), dataset: dataset))
        let (profile, _) = TestSupport.profile()
        func share(_ prior: TastePrior?) throws -> Int {
            var hits = 0
            for seed in UInt64(1)...30 {
                let model = try PickPriceModel(context: .make(dataset: dataset, profile: profile, seed: seed, prior: prior))
                hits += model.session.rounds.flatMap(\.artworkIDs)
                    .filter { dataset.department(of: $0) == .impressionistModern }.count
            }
            return hits
        }
        #expect(try share(prior) > share(nil))
    }

    @Test("Difficulty: Settings override, else the prior's default, else the ramp")
    func difficulty() throws {
        let settings = SettingsModel(store: InMemorySettingsStore())
        let prior = try #require(OnboardingService.prior(for: OnboardingAnswers(intent: .testMyEye),
                                                         dataset: TestSupport.dataset))
        #expect(settings.difficulty(prior: nil) == nil)
        #expect(settings.difficulty(prior: prior) == .hard)
        settings.settings.difficulty = .easy
        #expect(settings.difficulty(prior: prior) == .easy)
    }
}
