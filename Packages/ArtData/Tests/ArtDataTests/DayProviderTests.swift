import ArtCore
import Foundation
import Testing

@testable import ArtData

@Suite("Day provider")
struct DayProviderTests {
    static func instant(_ iso: String) -> Date {
        try! Date(iso, strategy: .iso8601)
    }

    @Test func negativeOffsetLateEveningIsStillTheLocalDay() {
        // 23:30 in Los Angeles (UTC−7 in October) is already the next day in UTC.
        let date = Self.instant("2026-10-12T06:30:00Z")
        let la = SystemDayProvider(timeZone: TimeZone(identifier: "America/Los_Angeles")!, now: { date })
        let utc = SystemDayProvider(timeZone: TimeZone(identifier: "UTC")!, now: { date })
        #expect(la.today() == DayKey(year: 2026, month: 10, day: 11))
        #expect(utc.today() == DayKey(year: 2026, month: 10, day: 12))
    }

    @Test func boundaryMinutesAroundMidnight() {
        let honolulu = TimeZone(identifier: "Pacific/Honolulu")!  // UTC−10, no DST
        #expect(SystemDayProvider.dayKey(for: Self.instant("2026-10-12T09:59:59Z"), in: honolulu).isoString == "2026-10-11")
        #expect(SystemDayProvider.dayKey(for: Self.instant("2026-10-12T10:00:00Z"), in: honolulu).isoString == "2026-10-12")
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!  // UTC+9
        #expect(SystemDayProvider.dayKey(for: Self.instant("2026-10-11T15:00:00Z"), in: tokyo).isoString == "2026-10-12")
        let newYearEve = Self.instant("2027-01-01T04:30:00Z")  // 23:30 on 31 Dec in New York
        #expect(SystemDayProvider.dayKey(for: newYearEve, in: TimeZone(identifier: "America/New_York")!).isoString
            == "2026-12-31")
    }

    @Test func nextDayStartHandlesDST() {
        let la = TimeZone(identifier: "America/Los_Angeles")!
        #expect(SystemDayProvider.nextDayStart(after: Self.instant("2026-10-12T06:30:00Z"), in: la)
            == Self.instant("2026-10-12T07:00:00Z"))
        // 1 Nov 2026 is the 25-hour fall-back day in Los Angeles: midnight after it is 08:00Z.
        #expect(SystemDayProvider.nextDayStart(after: Self.instant("2026-11-01T20:00:00Z"), in: la)
            == Self.instant("2026-11-02T08:00:00Z"))
    }

    @Test func fixedProviderAndLaunchArguments() {
        let day = DayKey(year: 2026, month: 10, day: 11)
        #expect(FixedDayProvider(dayKey: day).today() == day)
        let options = LaunchOptions(arguments: ["ArtPrice", "-uiTesting", "-fixedDay", "2026-10-11", "-resetState"])
        #expect(options == LaunchOptions(uiTesting: true, fixedDay: day, resetState: true))
        #expect(options.dayProvider.today() == day)
        #expect(LaunchOptions.fixedDay(in: ["-fixedDay", "2026-02-30"]) == nil)
        #expect(LaunchOptions.fixedDay(in: ["-fixedDay"]) == nil)
        #expect(LaunchOptions.fixedDay(in: ["-fixedDay", "2026-1-5"]) == nil)
        #expect(LaunchOptions(arguments: []) == LaunchOptions())
    }
}

@Suite("Settings")
struct SettingsTests {
    func freshDefaults() -> (UserDefaults, String) {
        let suite = "ArtDataTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    @Test func defaultsOnFreshInstall() {
        let (defaults, suite) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = UserDefaultsSettingsStore(defaults: defaults).load()
        #expect(settings == Settings.defaults)
        #expect(settings.haptics && settings.sound && settings.showAuctionHouses)
        #expect(settings.appearance == .system)
        #expect(settings.difficulty == nil)
    }

    @Test func roundTripAndReset() {
        let (defaults, suite) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsSettingsStore(defaults: defaults)
        let custom = Settings(haptics: false, sound: false, appearance: .dark, showAuctionHouses: false)
        store.save(custom)
        #expect(UserDefaultsSettingsStore(defaults: defaults).load() == custom)
        store.reset()
        #expect(store.load() == .defaults)
    }

    @Test func unknownAppearanceFallsBack() {
        let (defaults, suite) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("sepia", forKey: UserDefaultsSettingsStore.Key.appearance)
        defaults.set(false, forKey: UserDefaultsSettingsStore.Key.sound)
        let settings = UserDefaultsSettingsStore(defaults: defaults).load()
        #expect(settings.appearance == .system)
        #expect(settings.sound == false)
    }

    @Test func difficultyPersistsAndClears() {
        let (defaults, suite) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsSettingsStore(defaults: defaults)
        store.save(Settings(difficulty: .hard))
        #expect(UserDefaultsSettingsStore(defaults: defaults).load().difficulty == .hard)
        var s = store.load()
        s.difficulty = nil
        store.save(s)
        #expect(store.load().difficulty == nil)
        #expect(defaults.object(forKey: UserDefaultsSettingsStore.Key.difficulty) == nil)
        defaults.set("insane", forKey: UserDefaultsSettingsStore.Key.difficulty)
        #expect(store.load().difficulty == nil)
        store.save(Settings(difficulty: .easy))
        store.reset()
        #expect(store.load() == .defaults)
    }

    @Test func legacyOnboardingFlagIsTakenOnce() {
        let (defaults, suite) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsSettingsStore(defaults: defaults)
        #expect(store.takeLegacyHasOnboarded() == nil)
        defaults.set(true, forKey: UserDefaultsSettingsStore.Key.legacyHasOnboarded)
        #expect(store.takeLegacyHasOnboarded() == true)
        #expect(store.takeLegacyHasOnboarded() == nil)
    }

    @Test func inMemoryStore() {
        let store = InMemorySettingsStore()
        var s = store.load()
        s.haptics = false
        store.save(s)
        #expect(store.load().haptics == false)
        store.reset()
        #expect(store.load() == .defaults)
    }
}
