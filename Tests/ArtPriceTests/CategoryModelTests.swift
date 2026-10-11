import ArtDesign
import ArtCore
import ArtData
import Testing
@testable import ArtPrice

@Suite("Category quiz model")
struct CategoryModelTests {
    @Test("Same seed, same rounds", arguments: TestSupport.seeds)
    func deterministic(seed: UInt64) throws {
        let (profile, _) = TestSupport.profile()
        let a = try CategoryModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: seed))
        let b = try CategoryModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: seed))
        #expect(a.session.rounds == b.session.rounds)
        #expect(a.totalRounds == 10)
        #expect(a.optionLabels.count == 4)
    }

    @Test("Scoring, records and summary")
    func play() async throws {
        let (profile, store) = TestSupport.profile()
        let model = try CategoryModel(context: .make(dataset: TestSupport.dataset, profile: profile, seed: 3))
        var correct = 0
        while let round = model.round, !model.isOver {
            let right = model.session.index % 3 != 2
            let outcome = try #require(model.choose(right ? round.correctIndex : (round.correctIndex + 1) % 4))
            if right {
                #expect(outcome.categoryMatch == .correct)
                correct += 1
            } else {
                #expect(outcome.isCorrect == (outcome.categoryMatch == .alternate))
            }
            model.advance()
        }
        let summary = model.summary()
        #expect(summary.headline == "\(model.correctCount)/10")
        #expect(model.correctCount >= correct)
        #expect(summary.shareCaption?.hasPrefix("Movements mastered") == true)
        await profile.drain()
        #expect(await store.roundLog().records.count == 10)
        #expect(profile.stats(.category).sessionsCompleted == 1)
    }

    @Test("Accepted alternates count as correct with a note")
    func alternate() throws {
        let dataset = TestSupport.dataset
        let ids = dataset.categories.prefix(4).map(\.id)
        let round = CategoryRound(artwork: dataset.pool.artworks[0].id, options: Array(ids), correctIndex: 0,
                                  accepted: [ids[2]], difficulty: .easy)
        let outcome = Scorer.score(.category(round), .category(index: 2))
        #expect(outcome.isCorrect == true)
        #expect(outcome.categoryMatch == .alternate)
        let note = CategoryCopy.note(for: outcome, round: round, chosen: 2, dataset: dataset)
        #expect(note.hasPrefix("Also accepted: \(CategoryCopy.label(ids[2], dataset: dataset))"))
        #expect(note.contains(CategoryCopy.label(ids[0], dataset: dataset)))
        let miss = Scorer.score(.category(round), .category(index: 1))
        #expect(CategoryCopy.note(for: miss, round: round, chosen: 1, dataset: dataset)
            == "It's \(CategoryCopy.label(ids[0], dataset: dataset)).")
    }
}
