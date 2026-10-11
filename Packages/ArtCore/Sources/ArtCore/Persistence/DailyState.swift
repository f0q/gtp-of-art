/// Persisted daily-challenge state.
public struct DailyState: Codable, Sendable, Equatable {
    public var streak: Int
    public var bestStreak: Int
    public var lastCompletedDay: DayKey?
    /// Score per completed day, keyed `"yyyy-MM-dd"`.
    public var scores: [String: Int]

    public init(streak: Int = 0, bestStreak: Int = 0, lastCompletedDay: DayKey? = nil, scores: [String: Int] = [:]) {
        self.streak = streak
        self.bestStreak = bestStreak
        self.lastCompletedDay = lastCompletedDay
        self.scores = scores
    }

    enum CodingKeys: String, CodingKey {
        case streak
        case bestStreak = "best_streak"
        case lastCompletedDay = "last_completed_day"
        case scores
    }

    /// True if `day` has already been completed (replays are practice).
    public func hasCompleted(_ day: DayKey) -> Bool { scores[day.isoString] != nil }

    /// Records completion of `day` with `score`, applying `Streak.update`. A replay of a day
    /// already completed changes nothing.
    public func completing(_ day: DayKey, score: Int) -> DailyState {
        guard !hasCompleted(day) else { return self }
        var s = self
        let update = Streak.update(streak: streak, lastDay: lastCompletedDay, today: day)
        s.streak = update.streak
        s.lastCompletedDay = update.lastDay
        s.bestStreak = max(s.bestStreak, s.streak)
        s.scores[day.isoString] = score
        return s
    }

    /// Streak to display on `today` (see `Streak.displayed`).
    public func displayedStreak(today: DayKey) -> Int {
        Streak.displayed(streak: streak, lastDay: lastCompletedDay, today: today)
    }
}
