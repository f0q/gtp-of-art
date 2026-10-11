import ArtCore

/// Resolves an artwork id to its nine taste buckets (`TasteBuckets.buckets(for:)`), used to rebuild
/// the taste profile from swipe records. Nil for unknown works (they are skipped).
public typealias TasteBucketResolver = @Sendable (ArtworkID) -> [String]?

/// Where a loaded profile came from.
public enum ProfileSource: Sendable, Equatable {
    /// `profile.json` decoded at the current schema.
    case file
    /// `profile.json` decoded after migrating from an older schema.
    case migrated(fromSchema: Int)
    /// No profile and no history: a fresh profile.
    case created
    /// `profile.json` was missing, corrupt or from a newer app; stats were rebuilt from `rounds.jsonl`.
    case rebuilt(reason: String)
}

/// Result of loading the profile.
public struct ProfileLoadReport: Sendable, Equatable {
    public var profile: PlayerProfile
    public var source: ProfileSource
    /// `rounds.jsonl` lines that could not be decoded (only read when rebuilding).
    public var skippedLines: [SkippedLine]
}

/// Persists the player profile and the append-only round history (plan D6).
///
/// `rounds.jsonl` is the source of truth; `profile.json` is a cache of derived stats plus the few
/// fields that cannot be derived (onboarding, tips, local player id, taste undo state).
/// Swipe records should be appended once the undo window has closed, so a rebuilt taste profile
/// matches the live one.
public protocol ProfileStoring: Sendable {
    /// Loads (or creates/rebuilds) the profile and caches it. Later calls return the cached state.
    func load() async -> ProfileLoadReport
    /// The current profile (loads on first use).
    func profile() async -> PlayerProfile
    /// Replaces the profile. File-backed stores write it after a short debounce; call `flush()`
    /// when the app moves to the background.
    func save(_ profile: PlayerProfile) async
    /// Appends one answered round to the history immediately.
    func append(_ record: RoundRecord) async throws
    /// Appends an onboarding entry to the history immediately (default: no-op, for older conformers).
    func appendOnboarding(_ entry: OnboardingLogEntry) async throws
    /// Reads the whole round history, skipping (and reporting) lines that do not decode.
    func roundLog() async -> RoundLogContents
    /// Writes any pending profile now.
    func flush() async throws
    /// Recomputes stats, daily state, taste (when a bucket resolver is available) and the onboarding
    /// prior from the history, keeping the non-derivable fields; saves and returns the result.
    func rebuildStats() async throws -> PlayerProfile
    /// Deletes the profile and history and starts a fresh profile.
    func reset() async throws -> PlayerProfile
}

extension ProfileStoring {
    public func appendOnboarding(_ entry: OnboardingLogEntry) async throws {}
}
