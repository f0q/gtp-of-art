import ArtCore
import ArtData
import Foundation

/// Paths and helpers shared by the ArtData tests.
enum TestSupport {
    /// The repository's `Resources/` directory, resolved from this file's location.
    static let resourcesDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // ArtDataTests
        .appendingPathComponent("../../../../Resources", isDirectory: true)
        .standardizedFileURL

    /// The real bundled dataset (decoded once).
    static let dataset: BundledDataset = {
        do {
            return try BundledDataset(resourcesDirectory: resourcesDirectory)
        } catch {
            fatalError("cannot load the real dataset: \(error)")
        }
    }()

    /// A fresh empty temporary directory.
    static func makeTempDirectory(_ label: String = #function) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArtDataTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

extension TestSupport {
    /// The real dataset with every category's `min_quiz_items` lowered to `minQuizItems`, so the
    /// category quiz (and therefore the daily challenge) can generate on the small v0 data.
    static func dataset(minQuizItems: Int) -> BundledDataset {
        let real = dataset
        let categories = real.categories.map { c -> ArtCore.Category in
            var c = c
            c.minQuizItems = minQuizItems
            return c
        }
        var catalog = real.catalog
        catalog.datasetID = real.datasetVersion + "-quiz\(minQuizItems)"
        return BundledDataset(
            catalog: catalog, taxonomy: Taxonomy(categories: categories), tasteBaseline: real.tasteBaseline,
            statuses: real.statuses, images: real.images)
    }
}

/// Plays sessions with a scripted player and mirrors what the app does live, so persistence tests
/// can compare a rebuilt profile with the live one.
struct ScriptedPlayer {
    var profile = PlayerProfile(hasOnboarded: true, localPlayerID: "test-player")
    var records: [RoundRecord] = []
    var clock: Int64 = 1_800_000_000
    let dataset: BundledDataset

    init(dataset: BundledDataset) {
        self.dataset = dataset
    }

    /// The answer this player gives: correct on even rounds, wrong on odd ones (likes even swipes).
    static func answer(for round: Round, index: Int) -> Answer {
        let correct = index % 2 == 0
        switch round {
        case .pickPrice(let r): return .pickPrice(index: correct ? r.correctIndex : (r.correctIndex + 1) % 4)
        case .higherLower(let r):
            return .higherLower(side: correct ? r.pricierSide : (r.pricierSide == .top ? .bottom : .top))
        case .category(let r): return .category(index: correct ? r.correctIndex : (r.correctIndex + 1) % 4)
        case .bid(let r):
            let exact = min(700, max(0, (r.actualMilli - 2000 + 5) / 10))
            return .bid(position: correct ? exact : (exact < 350 ? 700 : 0))
        case .swipe: return .swipe(liked: correct)
        }
    }

    /// Plays `session` to the end (or `limit` rounds), updating live stats/taste/daily and records.
    mutating func play(_ start: GameSession, day: DayKey? = nil, limit: Int = 1000) {
        var session = start
        var points = 0
        var streak = 0
        var longest = 0
        while let round = session.currentRound, session.outcomes.count < limit {
            let index = session.index
            let answer = Self.answer(for: round, index: index)
            guard let outcome = session.submit(answer) else { break }
            profile.stats[session.mode, default: ModeStats()] =
                profile.stats[session.mode, default: ModeStats()].recording(outcome)
            points += outcome.points
            switch outcome.isCorrect {
            case true?:
                streak += 1
                longest = max(longest, streak)
            case false?: streak = 0
            case nil: break
            }
            if case .swipe(let r) = round, let liked = outcome.liked {
                profile.taste = profile.taste.applying(TasteSwipe(artwork: dataset.artwork(r.artwork)!, liked: liked))
            }
            clock += 7
            records.append(
                RoundRecord(
                    mode: session.mode, sessionSeed: session.seed, roundIndex: index, round: round, answer: answer,
                    outcome: outcome, day: day, playedAt: clock))
            if session.isEndless { SessionFactory.extendIfNeeded(&session, dataset: dataset) }
        }
        if session.isFinished {
            profile.stats[session.mode] = profile.stats[session.mode]!.recordingSession(
                points: points, longestStreak: longest)
            if let day { profile = DailyService.recordCompletion(of: session, on: day, in: profile) }
        }
    }
}
