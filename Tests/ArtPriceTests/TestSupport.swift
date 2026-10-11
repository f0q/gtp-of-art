import ArtDesign
import ArtCore
import ArtData
import Foundation
@testable import ArtPrice

/// Shared fixtures: the bundled dataset (the test host is the app) and in-memory stores.
enum TestSupport {
    static var dataset: any DatasetProviding { AppEnvironment.preview.dataset }

    static func profile(_ store: InMemoryProfileStore = InMemoryProfileStore()) -> (ProfileModel, InMemoryProfileStore) {
        (ProfileModel(store: store, now: { Date(timeIntervalSince1970: 1_791_763_200) }), store)
    }

    nonisolated static let seeds: [UInt64] = [1, 42, 20_261_012, 0xDEAD_BEEF]
}
