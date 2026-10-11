/// Daily streak bookkeeping based on day numbers, so it is immune to DST and time-zone math.
public enum Streak {
    /// Result of recording a completed daily challenge.
    public struct Update: Sendable, Equatable {
        public var streak: Int
        public var lastDay: DayKey?

        public init(streak: Int, lastDay: DayKey?) {
            self.streak = streak
            self.lastDay = lastDay
        }
    }

    /// Applies the streak rule when the daily challenge for `today` is completed.
    ///
    /// - No previous day: streak becomes 1.
    /// - gap = today.dayNumber − lastDay.dayNumber:
    ///   gap == 1 → streak + 1; gap ≤ 0 → no change at all (already played, or clock/travel went
    ///   backwards; `lastDay` is kept); gap > 1 → streak resets to 1.
    public static func update(streak: Int, lastDay: DayKey?, today: DayKey) -> Update {
        guard let lastDay else {
            return Update(streak: 1, lastDay: today)
        }
        let gap = today.dayNumber - lastDay.dayNumber
        if gap == 1 {
            return Update(streak: streak + 1, lastDay: today)
        } else if gap <= 0 {
            return Update(streak: streak, lastDay: lastDay)
        } else {
            return Update(streak: 1, lastDay: today)
        }
    }

    /// The streak to *display* on `today`: the stored streak if the last completion was today or
    /// yesterday (or in the future), else 0 because the next completion will reset it.
    public static func displayed(streak: Int, lastDay: DayKey?, today: DayKey) -> Int {
        guard let lastDay else { return 0 }
        return today.dayNumber - lastDay.dayNumber <= 1 ? streak : 0
    }
}
