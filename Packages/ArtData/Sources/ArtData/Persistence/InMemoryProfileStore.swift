import ArtCore
import Foundation

/// `ProfileStoring` kept entirely in memory, for previews, UI tests and unit tests. Saves apply
/// immediately; `flush()` does nothing.
public actor InMemoryProfileStore: ProfileStoring {
    private var current: PlayerProfile
    private var records: [RoundRecord]
    private var onboarding: [OnboardingLogEntry] = []
    private let tasteBuckets: TasteBucketResolver?

    public init(
        profile: PlayerProfile = PlayerProfile(localPlayerID: "preview-player"), records: [RoundRecord] = [],
        tasteBuckets: TasteBucketResolver? = nil
    ) {
        current = profile
        self.records = records
        self.tasteBuckets = tasteBuckets
    }

    public func load() async -> ProfileLoadReport {
        ProfileLoadReport(profile: current, source: .file, skippedLines: [])
    }

    public func profile() async -> PlayerProfile { current }

    public func save(_ profile: PlayerProfile) async { current = profile }

    public func append(_ record: RoundRecord) async throws { records.append(record) }

    public func appendOnboarding(_ entry: OnboardingLogEntry) async throws { onboarding.append(entry) }

    public func roundLog() async -> RoundLogContents { RoundLogContents(records: records, onboarding: onboarding) }

    /// No-op: saves apply immediately. Await it in tests to mirror the file store's flush.
    public func flush() async throws {}

    /// No-op alias of `flush()` for tests that "drain" pending writes.
    public func drain() async {}

    public func rebuildStats() async throws -> PlayerProfile {
        current = ProfileRebuilder.rebuild(
            from: RoundLogContents(records: records, onboarding: onboarding), base: current, tasteBuckets: tasteBuckets)
        return current
    }

    public func reset() async throws -> PlayerProfile {
        records = []
        onboarding = []
        current = PlayerProfile(localPlayerID: UUID().uuidString)
        return current
    }
}
