import ArtCore

/// The day's challenge plus the player's state for it.
public struct DailyToday: Sendable, Equatable {
    /// The local day the challenge belongs to.
    public var day: DayKey
    /// `DailySeed` for the day.
    public var seed: UInt64
    /// A fresh playable session (5 rounds, daily recipe).
    public var session: GameSession
}

/// Daily status shown on the hub.
public struct DailyStatus: Sendable, Equatable {
    public var day: DayKey
    /// Already completed today; replaying is practice and changes nothing.
    public var isCompleted: Bool
    /// Today's recorded score, if completed.
    public var score: Int?
    /// Streak to display today (0 if the streak has lapsed).
    public var displayedStreak: Int
    public var bestStreak: Int
}

/// Composes ArtCore's daily challenge and streak rules with the local day and dataset.
public enum DailyService {
    /// The challenge for the provider's local day. Deterministic: two calls on the same day with
    /// the same dataset and rules version return equal values.
    public static func today(
        provider: any DayProviding, dataset: any DatasetProviding,
        dailyRulesVersion: Int = DailyChallenge.currentRulesVersion
    ) throws -> DailyToday {
        try challenge(for: provider.today(), dataset: dataset, dailyRulesVersion: dailyRulesVersion)
    }

    /// The challenge and hub status for the provider's local day. The profile's onboarding prior
    /// is deliberately ignored: the daily is identical for every player.
    public static func today(
        provider: any DayProviding, dataset: any DatasetProviding, profile: PlayerProfile,
        dailyRulesVersion: Int = DailyChallenge.currentRulesVersion
    ) throws -> (challenge: DailyToday, status: DailyStatus) {
        let challenge = try today(provider: provider, dataset: dataset, dailyRulesVersion: dailyRulesVersion)
        return (challenge, status(on: challenge.day, profile: profile))
    }

    /// The challenge for a specific day.
    public static func challenge(
        for day: DayKey, dataset: any DatasetProviding, dailyRulesVersion: Int = DailyChallenge.currentRulesVersion
    ) throws -> DailyToday {
        let seed = DailySeed.seed(day: day, datasetVersion: dataset.datasetVersion, dailyRulesVersion: dailyRulesVersion)
        let session = try DailyChallenge.session(
            dayKey: day, pool: dataset.pool, datasetVersion: dataset.datasetVersion,
            dailyRulesVersion: dailyRulesVersion)
        return DailyToday(day: day, seed: seed, session: session)
    }

    /// Hub status for `day`.
    public static func status(on day: DayKey, profile: PlayerProfile) -> DailyStatus {
        let daily = profile.daily
        return DailyStatus(
            day: day, isCompleted: daily.hasCompleted(day), score: daily.scores[day.isoString],
            displayedStreak: daily.displayedStreak(today: day), bestStreak: daily.bestStreak)
    }

    /// Records a finished daily session for `day` (streak via `DailyState.completing`; replays of
    /// a completed day change nothing). Returns the profile unchanged if the session is not finished.
    public static func recordCompletion(of session: GameSession, on day: DayKey, in profile: PlayerProfile)
        -> PlayerProfile
    {
        guard session.mode == .daily, session.isFinished else { return profile }
        var updated = profile
        updated.daily = profile.daily.completing(day, score: session.totalPoints)
        return updated
    }
}
