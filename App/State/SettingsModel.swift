import ArtCore
import ArtData
import Foundation
import Observation

/// Observable wrapper around `SettingsStoring`; every change is saved immediately.
@Observable
final class SettingsModel {
    var settings: Settings {
        didSet { if settings != oldValue { store.save(settings) } }
    }

    @ObservationIgnored private let store: any SettingsStoring

    init(store: any SettingsStoring) {
        self.store = store
        settings = store.load()
    }

    /// Session difficulty: the explicit Settings choice, else the prior's default, else the spec ramp (nil).
    func difficulty(prior: TastePrior?) -> Difficulty? {
        settings.difficulty ?? prior?.defaultDifficulty
    }
}
