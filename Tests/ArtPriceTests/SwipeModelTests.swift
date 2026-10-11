import ArtDesign
import ArtCore
import ArtData
import CoreGraphics
import Foundation
import Testing
@testable import ArtPrice

@Suite("Swipe model")
struct SwipeModelTests {
    private func make(seed: UInt64 = 7, store: InMemoryProfileStore = InMemoryProfileStore())
        throws -> (SwipeModel, ProfileModel, InMemoryProfileStore)
    {
        let (profile, store) = TestSupport.profile(store)
        let model = try SwipeModel(dataset: TestSupport.dataset, profile: profile, seed: seed, prior: nil)
        return (model, profile, store)
    }

    @Test("Same seed, same 20 cards", arguments: TestSupport.seeds)
    func deterministic(seed: UInt64) throws {
        let (a, _, _) = try make(seed: seed)
        let (b, _, _) = try make(seed: seed)
        #expect(a.game.rounds == b.game.rounds)
        #expect(a.total == 20)
        #expect(a.deck.count == 20)
        #expect(Set(a.deck.map(\.id)).count == 20, "no repeats")
        #expect(a.game.rounds.allSatisfy { $0.kind == .swipe })
    }

    @Test("Apply then undo restores the taste and the session exactly; nothing is recorded")
    func undoIsExact() async throws {
        let (model, profile, store) = try make()
        let before = model.taste
        let beforeGame = model.game
        let top = try #require(model.topArtwork)
        #expect(model.swipe(liked: true))
        #expect(model.taste == before.applying(TasteSwipe(artwork: top, liked: true)))
        #expect(model.taste.swipeCount == 1 && model.taste.likeCount == 1)
        #expect(model.canUndo)
        #expect(model.undo())
        #expect(model.taste == before)
        #expect(model.game == beforeGame)
        #expect(model.topArtwork?.id == top.id)
        #expect(!model.canUndo)
        #expect(!model.undo(), "one level only")
        await profile.drain()
        #expect(await store.roundLog().records.isEmpty)
        #expect(profile.profile.taste == before)
    }

    @Test("A swipe is recorded only when the next swipe closes its undo window")
    func undoWindow() async throws {
        let (model, profile, store) = try make()
        let first = try #require(model.topArtwork)
        model.swipe(liked: true)
        await profile.drain()
        #expect(await store.roundLog().records.isEmpty)
        let second = try #require(model.topArtwork)
        model.swipe(liked: false)
        await profile.drain()
        let records = await store.roundLog().records
        #expect(records.count == 1)
        #expect(records.first?.round.artworkIDs == [first.id])
        #expect(profile.profile.taste == TasteProfile().applying(TasteSwipe(artwork: first, liked: true)))
        #expect(model.taste == profile.profile.taste.applying(TasteSwipe(artwork: second, liked: false)))
        model.undo()
        #expect(model.taste == profile.profile.taste)
        model.close()
        await profile.drain()
        #expect(await store.roundLog().records.count == 1, "undone swipe never recorded")
    }

    @Test("Progress copy appears from card 8")
    func progressCopy() throws {
        let (model, _, _) = try make()
        for _ in 0..<6 { model.swipe(liked: false) }
        #expect(model.currentCard == 7)
        #expect(model.progressCopy == nil)
        model.swipe(liked: true)
        #expect(model.progressCopy == "12 more to reveal your taste")
        for _ in 0..<11 { model.swipe(liked: true) }
        #expect(model.currentCard == 19)
        #expect(model.progressCopy == "1 more to reveal your taste")
        model.swipe(liked: true)
        #expect(model.progressCopy == "Last one, then your taste")
    }

    @Test("Scripted 20-swipe session: reveal numbers equal ArtCore's; history rebuilds the same taste")
    func scriptedSession() async throws {
        let dataset = TestSupport.dataset
        let store = InMemoryProfileStore(
            profile: PlayerProfile(localPlayerID: "t"), tasteBuckets: dataset.tasteBucketResolver)
        let (model, profile, _) = try make(seed: 20_261_012, store: store)
        var expected = TasteProfile()
        var likedIDs: [ArtworkID] = []
        var n = 0
        while !model.isFinished {
            let top = try #require(model.topArtwork)
            let liked = SwipeDebug.likes(n)
            expected = expected.applying(TasteSwipe(artwork: top, liked: liked))
            if liked { likedIDs.append(top.id) }
            #expect(model.swipe(liked: liked))
            n += 1
        }
        #expect(n == 20)
        #expect(!model.canUndo)
        let reading = try #require(model.reading)
        #expect(profile.profile.taste == expected)
        let report = TasteAnalyzer.analyze(expected, baseline: dataset.tasteBaseline)
        #expect(reading.report == report)
        #expect(reading.rarity == RarityCalculator.rarity(for: report, baseline: dataset.tasteBaseline))
        #expect(reading.rarity.visibility == .band)
        #expect(reading.archetype.id == report.archetypeID)
        #expect(reading.edition == reading.rarity.editionNumber)
        #expect(reading.session?.liked.map(\.id) == likedIDs)
        #expect(reading.session?.wall.count == min(likedIDs.count, TasteSessionResult.maxWall))
        let cost = likedIDs.compactMap { dataset.artwork($0)?.gamePrice?.usdAdjusted }.reduce(0, +)
        #expect(reading.session?.wallCostUSD == (cost == 0 ? nil : cost))

        await profile.drain()
        let log = await store.roundLog()
        #expect(log.records.count == 20)
        #expect(log.records.map(\.roundIndex) == Array(0..<20))
        #expect(profile.stats(.swipe).sessionsCompleted == 1)
        let rebuilt = try await store.rebuildStats()
        #expect(rebuilt.taste == expected)
    }

    @Test("Prior from the context is used for weighted picks")
    func priorChangesDeal() throws {
        let (profile, _) = TestSupport.profile()
        let answers = OnboardingAnswers(era: .modern)
        let prior = TastePrior.from(answers: answers)
        let plain = try SwipeModel(dataset: TestSupport.dataset, profile: profile, seed: 3, prior: nil)
        let weighted = try SwipeModel(dataset: TestSupport.dataset, profile: profile, seed: 3, prior: prior)
        #expect(plain.game.rounds != weighted.game.rounds)
    }

    @Test("Upcoming artworks are the next three cards")
    func upcoming() throws {
        let (model, _, _) = try make(seed: 5)
        #expect(model.upcomingArtworks.map(\.id) == Array(model.deck.dropFirst().prefix(3).map(\.id)))
    }
}

@Suite("Swipe card layout")
struct SwipeCardLayoutTests {
    private let container = CGSize(width: 353, height: 620)

    @Test("Landscape fills the width minus the inset; portrait fills the capped height")
    func fits() {
        let cap: CGFloat = 480
        let land = SwipeCardLayout(container: container, aspect: 1.6, maxArtworkHeight: cap, captionReserve: 64)
        #expect(land.image.width == container.width - 2 * 16)
        #expect(abs(land.image.height - land.image.width / 1.6) < 0.001)
        let available = min(cap, container.height - (2 * 16 + 12 + 64))
        let innerWidth = container.width - 2 * 16
        // Aspect-fit to both limits: height = min(available, innerWidth / aspect).
        for aspect: CGFloat in [0.7, 0.5] {
            let port = SwipeCardLayout(container: container, aspect: aspect, maxArtworkHeight: cap, captionReserve: 64)
            let height = min(available, innerWidth / aspect)
            #expect(abs(port.image.height - height) < 0.001)
            #expect(abs(port.image.width - height * aspect) < 0.001)
            #expect(port.image.width <= innerWidth + 0.001)
        }
        let tall = SwipeCardLayout(container: container, aspect: 0.5, maxArtworkHeight: cap, captionReserve: 64)
        #expect(tall.image.height == available, "a tall portrait is capped by the available height")
        let port = SwipeCardLayout(container: container, aspect: 0.7, maxArtworkHeight: cap, captionReserve: 64)
        #expect(land.minCardHeight == port.minCardHeight, "same minimum: the stack never jumps")
        #expect(port.minCardHeight <= container.height)
    }
}
