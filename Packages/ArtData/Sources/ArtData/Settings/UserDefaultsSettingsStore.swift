import ArtCore
import Foundation
import Synchronization

/// `SettingsStoring` backed by `UserDefaults`, one key per field (prefix `artprice.settings.`).
/// Missing keys fall back to `Settings.defaults`; unknown appearance/difficulty values fall back too.
public struct UserDefaultsSettingsStore: SettingsStoring, @unchecked Sendable {
    // UserDefaults is documented as thread-safe; @unchecked because the SDK may not mark it Sendable.
    private let defaults: UserDefaults

    /// Keys used in `UserDefaults`.
    public enum Key {
        public static let haptics = "artprice.settings.haptics"
        public static let sound = "artprice.settings.sound"
        public static let appearance = "artprice.settings.appearance"
        public static let showAuctionHouses = "artprice.settings.showAuctionHouses"
        /// Difficulty raw value; absent = nil (use the prior's default).
        public static let difficulty = "artprice.settings.difficulty"
        /// Round-1 key, no longer written; see `takeLegacyHasOnboarded()`.
        public static let legacyHasOnboarded = "artprice.settings.hasOnboarded"
        public static let all = [haptics, sound, appearance, showAuctionHouses, difficulty]
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> Settings {
        let d = Settings.defaults
        return Settings(
            haptics: bool(Key.haptics) ?? d.haptics,
            sound: bool(Key.sound) ?? d.sound,
            appearance: defaults.string(forKey: Key.appearance).flatMap(AppearancePreference.init(rawValue:))
                ?? d.appearance,
            showAuctionHouses: bool(Key.showAuctionHouses) ?? d.showAuctionHouses,
            difficulty: defaults.string(forKey: Key.difficulty).flatMap(Difficulty.init(rawValue:)) ?? d.difficulty)
    }

    public func save(_ settings: Settings) {
        defaults.set(settings.haptics, forKey: Key.haptics)
        defaults.set(settings.sound, forKey: Key.sound)
        defaults.set(settings.appearance.rawValue, forKey: Key.appearance)
        if let difficulty = settings.difficulty {
            defaults.set(difficulty.rawValue, forKey: Key.difficulty)
        } else {
            defaults.removeObject(forKey: Key.difficulty)
        }
        defaults.set(settings.showAuctionHouses, forKey: Key.showAuctionHouses)
    }

    public func reset() {
        for key in Key.all + [Key.legacyHasOnboarded] { defaults.removeObject(forKey: key) }
    }

    /// One-time migration: returns the round-1 `hasOnboarded` setting (if a build ever wrote it)
    /// and removes it, so the app can fold it into `PlayerProfile.hasOnboarded`.
    public func takeLegacyHasOnboarded() -> Bool? {
        let value = bool(Key.legacyHasOnboarded)
        defaults.removeObject(forKey: Key.legacyHasOnboarded)
        return value
    }

    private func bool(_ key: String) -> Bool? {
        defaults.object(forKey: key) as? Bool
    }
}

/// `SettingsStoring` in memory (previews, UI tests).
public final class InMemorySettingsStore: SettingsStoring {
    private let state: Mutex<Settings>

    public init(_ settings: Settings = .defaults) {
        state = Mutex(settings)
    }

    public func load() -> Settings { state.withLock { $0 } }
    public func save(_ settings: Settings) { state.withLock { $0 = settings } }
    public func reset() { state.withLock { $0 = .defaults } }
}
