import ArtCore
import Foundation
import Testing

@testable import ArtData

@Suite("Onboarding")
struct OnboardingTests {
    let data = TestSupport.dataset
    let answers = OnboardingAnswers(
        era: .modern, departments: [.impressionistModern], subjects: [.landscape], mood: .serene, intent: .learn)

    @Test func completeBuildsPriorSeedsAndOnboards() throws {
        let profile = OnboardingService.complete(answers: answers, profile: PlayerProfile(localPlayerID: "p"), dataset: data)
        let prior = try #require(profile.prior)
        #expect(prior == TastePrior.from(answers: answers))
        #expect(prior.highlightedMode == .category && prior.defaultDifficulty == .easy)
        #expect(profile.hasOnboarded)
        #expect(Set(profile.taste.seeds.keys) == Set(prior.seedBuckets))
        #expect(profile.taste.swipeCount == 0)
    }

    @Test func skippedQuestionnaireHasNoPriorAndUnknownDepartmentsAreDropped() {
        let skipped = OnboardingService.complete(
            answers: OnboardingAnswers(), profile: PlayerProfile(localPlayerID: "p"), dataset: data)
        #expect(skipped.prior == nil && skipped.hasOnboarded && skipped.taste.seeds.isEmpty)
        let odd = OnboardingAnswers(departments: ["martian_art", .asianArt])
        #expect(OnboardingService.sanitized(odd, dataset: data).departments == [.asianArt])
        #expect(OnboardingService.prior(for: OnboardingAnswers(departments: ["martian_art"]), dataset: data) == nil)
    }

    @Test func resetKeepsSwipesButDropsSeeds() throws {
        var profile = OnboardingService.complete(answers: answers, profile: PlayerProfile(localPlayerID: "p"), dataset: data)
        let work = try #require(data.pool.artworks.first)
        profile.taste = profile.taste.applying(TasteSwipe(artwork: work, liked: true))
        let reset = OnboardingService.reset(profile: profile)
        #expect(reset.prior == nil && !reset.hasOnboarded && reset.taste.seeds.isEmpty)
        #expect(reset.taste == TasteProfile().applying(TasteSwipe(artwork: work, liked: true)))
    }

    @Test func logLineFormat() throws {
        let entry = OnboardingLogEntry(
            action: .complete, answers: answers, prior: TastePrior.from(answers: answers), recordedAt: 1_800_000_000)
        let line = try #require(String(data: try RoundLog.line(for: entry), encoding: .utf8))
        #expect(line.hasSuffix("\n"))
        #expect(line.contains(#""kind":"onboarding""#) && line.contains(#""action":"complete""#))
        #expect(line.contains(#""recorded_at":1800000000"#))
        #expect(try JSONDecoder().decode(OnboardingLogEntry.self, from: Data(line.utf8)) == entry)
        let contents = RoundLog.decode(Data((line + #"{"kind":"future_thing","x":1}"# + "\n").utf8))
        #expect(contents.onboarding == [entry] && contents.records.isEmpty)
        #expect(contents.skipped == [SkippedLine(line: 2, reason: "unknown kind future_thing")])
    }

    @Test func roundTripsThroughFileStoreAndSurvivesRebuild() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        func store() -> FileProfileStore {
            FileProfileStore(directory: dir, tasteBuckets: data.tasteBucketResolver, makePlayerID: { "fresh" })
        }
        let s = store()
        let onboarded = try await OnboardingService.complete(answers: answers, store: s, dataset: data, now: 1)
        #expect(await store().profile() == onboarded)

        // Live play after onboarding, mirrored by the scripted player.
        var player = ScriptedPlayer(dataset: data)
        player.profile = onboarded
        player.play(try SessionFactory.make(mode: .swipe, dataset: data, seed: 5, prior: onboarded.prior))
        player.play(try SessionFactory.make(mode: .pickPrice, dataset: data, seed: 6, prior: onboarded.prior))
        await s.save(player.profile)
        for r in player.records { try await s.append(r) }
        try await s.flush()

        // Torn profile.json → rebuild from rounds.jsonl keeps prior, seeds and onboarding.
        let url = dir.appendingPathComponent("profile.json")
        try Data("{\"schema_ver".utf8).write(to: url)
        let rebuilt = await store().load()
        guard case .rebuilt = rebuilt.source else {
            Issue.record("expected rebuild, got \(rebuilt.source)")
            return
        }
        #expect(rebuilt.profile.prior == onboarded.prior)
        #expect(rebuilt.profile.hasOnboarded)
        #expect(rebuilt.profile.taste == player.profile.taste)
        #expect(rebuilt.profile.stats == player.profile.stats)

        // Redo questionnaire: logged too, so a later rebuild agrees.
        let reset = try await OnboardingService.reset(store: store(), now: 2)
        #expect(reset.prior == nil && !reset.hasOnboarded)
        try FileManager.default.removeItem(at: url)
        let afterReset = await store().load().profile
        #expect(afterReset.prior == nil && !afterReset.hasOnboarded && afterReset.taste.seeds.isEmpty)
        #expect(afterReset.taste.swipeCount == player.profile.taste.swipeCount)
    }

    @Test func rebuildWithoutOnboardingLinesKeepsProfilePrior() async throws {
        let store = InMemoryProfileStore(
            profile: OnboardingService.complete(answers: answers, profile: PlayerProfile(localPlayerID: "m"), dataset: data),
            tasteBuckets: data.tasteBucketResolver)
        let before = await store.profile()
        let rebuilt = try await store.rebuildStats()
        #expect(rebuilt.prior == before.prior && rebuilt.hasOnboarded && rebuilt.taste == before.taste)
    }
}
