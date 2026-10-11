import ArtCore
import ArtData
import ArtDesign
import Foundation
import SnapshotTesting
import SwiftUI
import Testing
import UIKit
@testable import ArtPrice

/// Taste reveal (final frame), taste profile and collection; recorded on ArtCI-26 only.
@Suite(
    "Taste snapshots", .snapshots(record: .missing),
    .enabled(if: ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26))
struct TasteSnapshotTests {
    typealias Variant = SnapshotTests.Variant

    /// Services whose profile holds one scripted 20-swipe session.
    private func seededServices() -> AppServices {
        let services = AppServices(env: .preview)
        SwipeDebug.seedProfile(services.profile, dataset: services.env.dataset)
        return services
    }

    private func scriptedReading() throws -> TasteReading {
        let (profile, _) = TestSupport.profile()
        let model = try SwipeModel(dataset: TestSupport.dataset, profile: profile, seed: 20_261_012, prior: nil)
        var n = 0
        while !model.isFinished {
            model.swipe(liked: SwipeDebug.likes(n))
            n += 1
        }
        return try #require(model.reading)
    }

    private func assertScreen(_ view: some View, _ variant: Variant, testName: String = #function) {
        let hosted = variant.apply(view).background(Tokens.Color.bgCanvas)
        assertSnapshot(
            of: hosted,
            as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhone13Pro), traits: variant.traits),
            named: variant.rawValue, testName: testName)
    }

    @Test("Taste reveal, final frame", arguments: Variant.allCases)
    func tasteReveal(_ variant: Variant) throws {
        let services = AppServices(env: .preview)
        let view = TasteRevealView(
            reading: try scriptedReading(), actions: SessionActions(playAgain: {}, close: {}), startsComplete: true)
            .appServices(services)
        assertScreen(view, variant)
    }

    @Test("Taste profile screen", arguments: Variant.allCases)
    func tasteProfile(_ variant: Variant) throws {
        let services = seededServices()
        let liked = try scriptedReading().session?.liked ?? []
        let view = NavigationStack { TasteProfileView(likedOverride: liked) }.appServices(services)
        assertScreen(view, variant)
    }

    @Test("Taste share card (feed and story)", arguments: TasteShareFormat.allCases)
    func shareCard(_ format: TasteShareFormat) throws {
        let card = ShareCardFactory.taste(try scriptedReading(), images: [:], dataset: TestSupport.dataset, format: format)
        assertSnapshot(
            of: Variant.dark.apply(card),
            as: .image(perceptualPrecision: 0.98, layout: .fixed(width: format.size.width, height: format.size.height),
                       traits: Variant.dark.traits),
            named: format == .feed ? "feed" : "story")
    }
}
