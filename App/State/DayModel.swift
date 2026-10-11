import ArtCore
import ArtData
import Foundation
import Observation

/// "Today" as a local calendar day; recomputed when the scene becomes active or the day changes.
@Observable
final class DayModel {
    private(set) var today: DayKey
    @ObservationIgnored private let provider: any DayProviding

    init(provider: any DayProviding) {
        self.provider = provider
        today = provider.today()
    }

    func refresh() {
        let now = provider.today()
        if now != today { today = now }
    }
}
