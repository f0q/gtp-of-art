import ArtCore

/// Colour scheme preference. The design follows the system by default (plan C1/C9).
public enum AppearancePreference: String, Codable, Sendable, CaseIterable {
    case system
    case dark
}

/// User settings (stored in `UserDefaults`). A plain value; the app wraps a store in an
/// `@Observable` model. Onboarding state is not a setting: `PlayerProfile.hasOnboarded` owns it.
public struct Settings: Codable, Sendable, Equatable {
    public var haptics: Bool
    public var sound: Bool
    public var appearance: AppearancePreference
    /// Show auction house / venue names on reveals.
    public var showAuctionHouses: Bool
    /// Preferred difficulty for standalone sessions; nil = use the onboarding prior's default.
    public var difficulty: Difficulty?

    public init(
        haptics: Bool = true, sound: Bool = true, appearance: AppearancePreference = .system,
        showAuctionHouses: Bool = true, difficulty: Difficulty? = nil
    ) {
        self.haptics = haptics
        self.sound = sound
        self.appearance = appearance
        self.showAuctionHouses = showAuctionHouses
        self.difficulty = difficulty
    }

    /// Defaults for a fresh install.
    public static let defaults = Settings()
}

/// Reads and writes `Settings`.
public protocol SettingsStoring: Sendable {
    func load() -> Settings
    func save(_ settings: Settings)
    /// Removes stored values so `load()` returns `Settings.defaults`.
    func reset()
}
