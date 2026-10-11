/// Everything persisted about the local player (`profile.json`).
public struct PlayerProfile: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var hasOnboarded: Bool
    /// Encoded as a JSON object keyed by mode raw value.
    public var stats: [GameMode: ModeStats]
    public var taste: TasteProfile
    public var daily: DailyState
    public var seenTips: [String]
    /// Random UUID string generated on first launch by the app.
    public var localPlayerID: String
    /// Preferences from the onboarding questionnaire; nil if skipped or never run.
    /// `hasOnboarded` in this struct is the single source of truth for onboarding state.
    public var prior: TastePrior?

    public init(
        schemaVersion: Int = currentSchemaVersion, hasOnboarded: Bool = false, stats: [GameMode: ModeStats] = [:],
        taste: TasteProfile = TasteProfile(), daily: DailyState = DailyState(), seenTips: [String] = [],
        localPlayerID: String, prior: TastePrior? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.hasOnboarded = hasOnboarded
        self.stats = stats
        self.taste = taste
        self.daily = daily
        self.seenTips = seenTips
        self.localPlayerID = localPlayerID
        self.prior = prior
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case hasOnboarded = "has_onboarded"
        case stats, taste, daily
        case seenTips = "seen_tips"
        case localPlayerID = "local_player_id"
        case prior
    }
}
