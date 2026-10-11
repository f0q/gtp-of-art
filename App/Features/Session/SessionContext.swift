import ArtCore
import ArtData
import Foundation

/// Everything a mode model needs to deal a session: dataset, profile, seed, difficulty and prior.
struct SessionContext {
    var dataset: any DatasetProviding
    var profile: ProfileModel
    var seed: UInt64
    /// nil plays the spec recipe (ramp); a value plays 10 rounds at that difficulty.
    var difficulty: Difficulty?
    /// Onboarding prior: weighted artwork picks (ignored by the daily).
    var prior: TastePrior?
    var dayProvider: any DayProviding

    /// Builds a standalone session for `mode` from this context.
    func makeSession(_ mode: GameMode) throws -> GameSession {
        try SessionFactory.make(mode: mode, difficulty: difficulty, dataset: dataset, seed: seed, prior: prior)
    }
}

extension SessionContext {
    /// A context for tests and previews.
    static func make(
        dataset: any DatasetProviding, profile: ProfileModel, seed: UInt64, difficulty: Difficulty? = nil,
        prior: TastePrior? = nil, day: DayKey = HomeContent.launchDay
    ) -> SessionContext {
        SessionContext(
            dataset: dataset, profile: profile, seed: seed, difficulty: difficulty, prior: prior,
            dayProvider: FixedDayProvider(dayKey: day))
    }
}
