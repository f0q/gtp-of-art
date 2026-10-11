/// Proves that a dataset generates a clean daily challenge for a range of days.
public enum DailyValidator {
    /// A day that failed validation.
    public struct Failure: Sendable, Equatable {
        public var day: DayKey
        public var reason: String

        public init(day: DayKey, reason: String) {
            self.day = day
            self.reason = reason
        }
    }

    /// Validation report.
    public struct Report: Sendable, Equatable {
        public var daysChecked: Int
        public var failures: [Failure]
        public var isValid: Bool { failures.isEmpty }

        public init(daysChecked: Int, failures: [Failure]) {
            self.daysChecked = daysChecked
            self.failures = failures
        }
    }

    /// Generates `days` consecutive challenges starting at `from` and checks each has 5 rounds,
    /// follows the recipe, and never repeats an artwork within the day.
    public static func check(
        _ pool: GamePool, from start: DayKey, days: Int = 730, datasetVersion: String,
        dailyRulesVersion: Int = DailyChallenge.currentRulesVersion
    ) -> Report {
        var failures: [Failure] = []
        for offset in 0..<days {
            let day = start.adding(days: offset)
            do {
                let challenge = try DailyChallenge.make(
                    dayKey: day, pool: pool, datasetVersion: datasetVersion, dailyRulesVersion: dailyRulesVersion)
                let kinds = challenge.rounds.map(\.kind)
                if kinds != DailyChallenge.recipe.map(\.kind) {
                    failures.append(Failure(day: day, reason: "round kinds \(kinds) do not match recipe"))
                }
                let ids = challenge.rounds.flatMap(\.artworkIDs)
                if Set(ids).count != ids.count {
                    failures.append(Failure(day: day, reason: "artwork repeated within the day"))
                }
            } catch {
                failures.append(Failure(day: day, reason: "\(error)"))
            }
        }
        return Report(daysChecked: days, failures: failures)
    }
}
