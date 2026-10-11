import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Every dependency the app uses, as protocol existentials (plan Part D3). `AppEnvironment` is the
/// only place live implementations are chosen; views read it with `@Environment(\.app)`.
nonisolated struct AppEnvironment: Sendable {
    var dataset: any DatasetProviding
    var profileStore: any ProfileStoring
    var dayProvider: any DayProviding
    var settingsStore: any SettingsStoring
    var imageLoader: ImageLoader
    var haptics: HapticsPolicy
    var seeds: SeedPolicy
    var launch: LaunchOptions
    var debug: DebugLaunch
    var now: @Sendable () -> Date
    /// Previews and snapshots: time-dependent text (countdowns) uses `now` instead of the wall clock.
    var freezesClock = false

    /// Live wiring: bundled dataset, `FileProfileStore` in Application Support/ArtPrice,
    /// `UserDefaults` settings, system or fixed day. `-uiTesting` swaps in in-memory stores and
    /// fixed seeds; `-resetState` wipes stored state first.
    static func live(arguments: [String] = ProcessInfo.processInfo.arguments, bundle: Bundle = .main) throws
        -> AppEnvironment
    {
        let launch = LaunchOptions(arguments: arguments)
        let dataset = try BundledDataset(bundle: bundle)
        let profileStore: any ProfileStoring
        let settingsStore: any SettingsStoring
        let debug = DebugLaunch(arguments: arguments)
        if launch.uiTesting {
            profileStore = InMemoryProfileStore(
                profile: PlayerProfile(hasOnboarded: debug.onboarded, localPlayerID: "ui-testing"))
            settingsStore = InMemorySettingsStore()
        } else {
            let directory = try FileProfileStore.defaultDirectory()
            let defaults = UserDefaultsSettingsStore()
            if launch.resetState {
                try? FileManager.default.removeItem(at: directory)
                defaults.reset()
            }
            profileStore = FileProfileStore(directory: directory)
            settingsStore = defaults
        }
        return AppEnvironment(
            dataset: dataset, profileStore: profileStore, dayProvider: launch.dayProvider,
            settingsStore: settingsStore, imageLoader: .shared,
            haptics: HapticsPolicy(suppressed: false), seeds: launch.uiTesting ? .fixed : .random, launch: launch,
            debug: debug,
            now: { Date() })
    }

    /// Previews, snapshots and unit tests: the bundled dataset (the test host is the app), in-memory
    /// stores, a fixed day and fixed seeds.
    static let preview: AppEnvironment = {
        guard let dataset = try? BundledDataset(bundle: .main) else {
            fatalError("AppEnvironment.preview needs the bundled dataset in Bundle.main")
        }
        let day = DayKey(year: 2026, month: 10, day: 12)
        return AppEnvironment(
            dataset: dataset,
            profileStore: InMemoryProfileStore(profile: PlayerProfile(hasOnboarded: true, localPlayerID: "preview")),
            dayProvider: FixedDayProvider(dayKey: day), settingsStore: InMemorySettingsStore(),
            imageLoader: .shared, haptics: HapticsPolicy(suppressed: true),
            seeds: .fixed, launch: LaunchOptions(uiTesting: true, fixedDay: day), debug: DebugLaunch(arguments: []),
            now: { Date(timeIntervalSince1970: 1_791_763_200) }, freezesClock: true)
    }()
}

extension EnvironmentValues {
    /// The app's dependencies (`AppEnvironment.live` at the root; `.preview` otherwise).
    @Entry var app: AppEnvironment = .preview
}

/// Whether semantic haptics may play: the Settings toggle, unless suppressed (previews, snapshots).
nonisolated struct HapticsPolicy: Sendable, Equatable {
    var suppressed: Bool

    func isEnabled(_ settings: Settings) -> Bool { !suppressed && settings.haptics }
}

/// Where session seeds come from. Random in normal play; fixed (per mode and attempt) for UI tests,
/// previews and screenshots so runs are reproducible.
nonisolated enum SeedPolicy: Sendable, Equatable {
    case random
    case fixed

    func seed(for mode: GameMode, attempt: Int) -> UInt64 {
        switch self {
        case .random: SessionFactory.randomSeed()
        case .fixed: fnv1a64("artprice|fixed|\(mode.rawValue)|\(attempt)")
        }
    }
}
