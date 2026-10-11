import ArtCore
import ArtData
import ArtDesign
import Foundation
import SnapshotTesting
import SwiftUI
import Testing
import UIKit
@testable import ArtPrice

/// Reference images are recorded on ArtCI-26 (iOS 26) only; other runtimes skip this suite.
@Suite(
    "Snapshots", .snapshots(record: .missing),
    .enabled(if: ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26))
struct SnapshotTests {
    nonisolated enum Variant: String, CaseIterable, Sendable {
        case light, dark, axXL

        @MainActor var traits: UITraitCollection {
            UITraitCollection { traits in
                traits.userInterfaceStyle = self == .light ? .light : .dark
                traits.preferredContentSizeCategory = self == .axXL ? .accessibilityExtraLarge : .large
            }
        }

        @MainActor func apply(_ view: some View) -> some View {
            view
                .environment(\.colorScheme, self == .light ? .light : .dark)
                .environment(\.dynamicTypeSize, self == .axXL ? .accessibility3 : .large)
                .environment(\.artReduceMotionOverride, true)
                .environment(\.artReduceTransparencyOverride, true)
        }
    }

    private func services() -> AppServices {
        AppServices(env: .preview)
    }

    private func assertScreen(_ view: some View, _ variant: Variant, testName: String = #function) {
        let hosted = variant.apply(view).background(Tokens.Color.bgCanvas)
        assertSnapshot(
            of: hosted,
            as: .image(perceptualPrecision: 0.98, layout: .device(config: .iPhone13Pro), traits: variant.traits),
            named: variant.rawValue, testName: testName)
    }

    @Test("Home hub", arguments: Variant.allCases)
    func home(_ variant: Variant) {
        let services = services()
        assertScreen(NavigationStack { HomeView() }.appServices(services), variant)
    }

    @Test("Pick the price reveal", arguments: Variant.allCases)
    func pickReveal(_ variant: Variant) throws {
        let services = services()
        let model = try PickPriceModel(context: .make(dataset: services.env.dataset, profile: services.profile, seed: 7))
        let round = try #require(model.round)
        model.choose(round.correctIndex)
        model.reveal.start(isHit: true, reduceMotion: true)
        model.reveal.skipToEnd()
        let view = PickPriceView(model: model, actions: SessionActions(playAgain: {}, close: {}))
            .appServices(services)
        assertScreen(view, variant)
    }

    @Test("Share card", arguments: Variant.allCases)
    func shareCard(_ variant: Variant) throws {
        let dataset = AppEnvironment.preview.dataset
        let featured = try #require(HomeContent.paintingOfTheDay(on: HomeContent.launchDay, dataset: dataset))
        let summary = SessionSummary(
            mode: .pickPrice, headline: "8/10", caption: "Pick the price · 950 points", detail: nil,
            marks: [.hit, .hit, .miss, .hit, .hit, .hit, .miss, .hit, .hit, .hit], featured: featured)
        let card = ShareCardFactory.card(summary, image: nil, locator: dataset)
        assertSnapshot(
            of: variant.apply(card),
            as: .image(perceptualPrecision: 0.98, layout: .fixed(width: ShareCardView.size.width,
                                                                 height: ShareCardView.size.height),
                       traits: variant.traits),
            named: variant.rawValue)
    }

    @Test("Onboarding step 1", arguments: Variant.allCases)
    func onboarding(_ variant: Variant) {
        let services = services()
        let model = OnboardingModel(dataset: services.env.dataset, profile: services.profile)
        assertScreen(OnboardingView(model: model).appServices(services), variant)
    }

    @Test("Category reveal", arguments: Variant.allCases)
    func categoryReveal(_ variant: Variant) throws {
        let services = services()
        let model = try CategoryModel(context: .make(dataset: services.env.dataset, profile: services.profile, seed: 7))
        let round = try #require(model.round)
        model.choose((round.correctIndex + 1) % 4)
        model.reveal.start(isHit: false, reduceMotion: true)
        model.reveal.skipToEnd()
        assertScreen(CategoryView(model: model, actions: SessionActions(playAgain: {}, close: {})).appServices(services),
                     variant)
    }

    @Test("Daily result", arguments: Variant.allCases)
    func dailyResult(_ variant: Variant) throws {
        let services = services()
        let model = try DailyModel(context: .make(dataset: services.env.dataset, profile: services.profile, seed: 0))
        model.playThrough { m in
            m.session.index == 2 ? DailyModelTests.wrongAnswer(m.session.currentRound) : m.bestAnswer()
        }
        assertScreen(DailyResultView(model: model, actions: SessionActions(playAgain: {}, close: {}))
            .appServices(services), variant)
    }
}
