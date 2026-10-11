import ArtCore
import ArtData
import Foundation
import Observation

/// The player's profile as the UI sees it, plus the write path for play history.
///
/// Stats update in memory immediately (so a personal best shows at once); persistence runs in a
/// serial chain of tasks so records are appended in order and each save carries the latest stats.
@Observable
final class ProfileModel {
    private(set) var profile: PlayerProfile
    private(set) var isLoaded = false
    /// The last persistence error, if any (shown nowhere yet; logged by tests).
    private(set) var lastError: String?

    @ObservationIgnored private let store: any ProfileStoring
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var tail: Task<Void, Never>?

    init(store: any ProfileStoring, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.now = now
        profile = PlayerProfile(localPlayerID: "")
    }

    func load() async {
        guard !isLoaded else { return }
        profile = await store.load().profile
        isLoaded = true
    }

    func stats(_ mode: GameMode) -> ModeStats {
        profile.stats[mode] ?? ModeStats()
    }

    /// Appends the answered round `roundIndex` of `session` and updates the mode's stats.
    func recordRound(of session: GameSession, at roundIndex: Int, day: DayKey? = nil) {
        guard session.outcomes.indices.contains(roundIndex) else { return }
        let record = RoundRecord(
            mode: session.mode, sessionSeed: session.seed, roundIndex: roundIndex, round: session.rounds[roundIndex],
            answer: session.answers[roundIndex], outcome: session.outcomes[roundIndex], day: day,
            playedAt: Int64(now().timeIntervalSince1970))
        profile.stats[session.mode] = stats(session.mode).recording(record.outcome)
        let snapshot = profile
        enqueue { store in
            try await store.append(record)
            await store.save(snapshot)
        }
    }

    /// Records a finished (or, for endless modes, ended) session's totals.
    func recordSession(mode: GameMode, points: Int, longestStreak: Int) {
        profile.stats[mode] = stats(mode).recordingSession(points: points, longestStreak: longestStreak)
        let snapshot = profile
        enqueue { store in await store.save(snapshot) }
    }

    /// Swipe mode: applies a swipe whose undo window has closed to the taste profile, then appends
    /// its round (so a taste profile rebuilt from `rounds.jsonl` matches the live one).
    func recordSwipe(of session: GameSession, at roundIndex: Int, swipe: TasteSwipe) {
        guard session.outcomes.indices.contains(roundIndex) else { return }
        profile.taste = profile.taste.applying(swipe)
        recordRound(of: session, at: roundIndex)
    }

    /// The round history after queued writes have landed (Collection, taste screen).
    func roundLog() async -> RoundLogContents {
        await drain()
        return await store.roundLog()
    }

    /// Finishes the questionnaire: sets the prior and taste seeds, marks the player onboarded,
    /// logs the answers to the history and flushes.
    func completeOnboarding(_ answers: OnboardingAnswers, dataset: any DatasetProviding) {
        profile = OnboardingService.complete(answers: answers, profile: profile, dataset: dataset)
        let stamp = Int64(now().timeIntervalSince1970)
        enqueue { store in
            try await OnboardingService.complete(answers: answers, store: store, dataset: dataset, now: stamp)
        }
    }

    /// "Redo questionnaire": clears the prior and shows onboarding again (stats are kept).
    func resetOnboarding() {
        profile = OnboardingService.reset(profile: profile)
        let stamp = Int64(now().timeIntervalSince1970)
        enqueue { store in try await OnboardingService.reset(store: store, now: stamp) }
    }

    /// Records a finished daily session for `day` (streak and score; replays change nothing).
    func recordDailyCompletion(of session: GameSession, on day: DayKey) {
        profile = DailyService.recordCompletion(of: session, on: day, in: profile)
        let snapshot = profile
        enqueue { store in await store.save(snapshot) }
    }

    /// Waits for queued writes.
    func drain() async {
        await tail?.value
    }

    /// Waits for queued writes, then forces the debounced profile to disk.
    func flush() async {
        await drain()
        do {
            try await store.flush()
        } catch {
            lastError = String(describing: error)
        }
    }

    private func enqueue(_ work: @escaping @Sendable (any ProfileStoring) async throws -> Void) {
        let previous = tail
        let store = store
        tail = Task {
            await previous?.value
            do {
                try await work(store)
            } catch {
                self.lastError = String(describing: error)
            }
        }
    }
}
