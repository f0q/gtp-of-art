import ArtCore
import Foundation

/// File-backed `ProfileStoring`: `profile.json` (atomic rewrite) and append-only `rounds.jsonl`
/// in one directory (Application Support/ArtPrice in the app, a temp directory in tests).
///
/// - `save` is debounced (500 ms by default): only the latest profile is written. `flush()` writes
///   immediately; the app calls it when the scene goes to the background.
/// - Loading migrates older schemas (`ProfileMigrator`). A missing, corrupt or newer-schema
///   `profile.json` is set aside (`profile.corrupt.json` / `profile.v<N>.json`) and the profile is
///   rebuilt from `rounds.jsonl`; undecodable history lines are skipped and reported.
public actor FileProfileStore: ProfileStoring {
    public static let profileFile = "profile.json"
    public static let roundsFile = "rounds.jsonl"

    /// Directory holding the two files.
    public nonisolated let directory: URL
    private let debounce: Duration
    private let migrator: ProfileMigrator
    private let tasteBuckets: TasteBucketResolver?
    private let makePlayerID: @Sendable () -> String

    private var cached: ProfileLoadReport?
    private var pending: PlayerProfile?
    private var saveGeneration = 0
    private var saveTask: Task<Void, Never>?
    /// The error from the most recent debounced write, if it failed.
    public private(set) var lastWriteError: String?

    public init(
        directory: URL, debounce: Duration = .milliseconds(500), migrator: ProfileMigrator = .standard,
        tasteBuckets: TasteBucketResolver? = nil,
        makePlayerID: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.directory = directory
        self.debounce = debounce
        self.migrator = migrator
        self.tasteBuckets = tasteBuckets
        self.makePlayerID = makePlayerID
    }

    /// The app's store directory: `Application Support/ArtPrice` (created if needed).
    public static func defaultDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return base.appendingPathComponent("ArtPrice", isDirectory: true)
    }

    nonisolated var profileURL: URL { directory.appendingPathComponent(Self.profileFile) }
    nonisolated var roundsURL: URL { directory.appendingPathComponent(Self.roundsFile) }

    // MARK: - ProfileStoring

    public func load() async -> ProfileLoadReport {
        if let cached { return cached }
        let report = loadFromDisk()
        cached = report
        return report
    }

    public func profile() async -> PlayerProfile {
        await load().profile
    }

    public func save(_ profile: PlayerProfile) async {
        if cached == nil { cached = loadFromDisk() }
        cached?.profile = profile
        pending = profile
        saveGeneration += 1
        let generation = saveGeneration
        let delay = debounce
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.writePendingIfCurrent(generation)
        }
    }

    public func append(_ record: RoundRecord) async throws {
        try ensureDirectory()
        try RoundLog.append(record, to: roundsURL)
    }

    public func appendOnboarding(_ entry: OnboardingLogEntry) async throws {
        try ensureDirectory()
        try RoundLog.append(entry, to: roundsURL)
    }

    public func roundLog() async -> RoundLogContents {
        RoundLog.read(from: roundsURL)
    }

    public func flush() async throws {
        saveTask?.cancel()
        saveTask = nil
        guard let profile = pending else { return }
        try write(profile)
        pending = nil
    }

    public func rebuildStats() async throws -> PlayerProfile {
        let base = await profile()
        let log = RoundLog.read(from: roundsURL)
        let rebuilt = ProfileRebuilder.rebuild(from: log, base: base, tasteBuckets: tasteBuckets)
        cached?.profile = rebuilt
        cached?.skippedLines = log.skipped
        pending = rebuilt
        try await flush()
        return rebuilt
    }

    public func reset() async throws -> PlayerProfile {
        saveTask?.cancel()
        saveTask = nil
        pending = nil
        let fm = FileManager.default
        for url in [profileURL, roundsURL] where fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
        let fresh = PlayerProfile(localPlayerID: makePlayerID())
        try write(fresh)
        cached = ProfileLoadReport(profile: fresh, source: .created, skippedLines: [])
        return fresh
    }

    // MARK: - Internals

    private func writePendingIfCurrent(_ generation: Int) {
        guard generation == saveGeneration, let profile = pending else { return }
        do {
            try write(profile)
            pending = nil
            lastWriteError = nil
        } catch {
            lastWriteError = String(describing: error)
        }
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Atomic rewrite: Foundation writes a temporary file and renames it over `profile.json`, so a
    /// crash leaves either the old or the new file, never a torn one.
    private func write(_ profile: PlayerProfile) throws {
        try ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(profile).write(to: profileURL, options: .atomic)
    }

    private func loadFromDisk() -> ProfileLoadReport {
        let fm = FileManager.default
        let reason: String
        if let data = try? Data(contentsOf: profileURL) {
            do {
                let (profile, version) = try migrator.decode(data)
                if version == migrator.currentVersion {
                    return ProfileLoadReport(profile: profile, source: .file, skippedLines: [])
                }
                try? write(profile)
                return ProfileLoadReport(profile: profile, source: .migrated(fromSchema: version), skippedLines: [])
            } catch ProfileMigrationError.newerSchema(let found, _) {
                setAside(suffix: "v\(found)")
                reason = "profile.json has newer schema \(found)"
            } catch {
                setAside(suffix: "corrupt")
                reason = "profile.json unreadable: \(RoundLog.reason(error))"
            }
        } else {
            reason = "profile.json missing"
        }
        let log = RoundLog.read(from: roundsURL)
        let hasHistory = fm.fileExists(atPath: roundsURL.path)
        var base = PlayerProfile(localPlayerID: makePlayerID())
        guard hasHistory else {
            try? write(base)
            return ProfileLoadReport(profile: base, source: .created, skippedLines: [])
        }
        base.hasOnboarded = !log.records.isEmpty
        let rebuilt = ProfileRebuilder.rebuild(from: log, base: base, tasteBuckets: tasteBuckets)
        try? write(rebuilt)
        return ProfileLoadReport(profile: rebuilt, source: .rebuilt(reason: reason), skippedLines: log.skipped)
    }

    /// Moves `profile.json` to `profile.<suffix>.json` (replacing an older copy) so it is not lost.
    private func setAside(suffix: String) {
        let fm = FileManager.default
        let target = directory.appendingPathComponent("profile.\(suffix).json")
        try? fm.removeItem(at: target)
        try? fm.moveItem(at: profileURL, to: target)
    }
}
