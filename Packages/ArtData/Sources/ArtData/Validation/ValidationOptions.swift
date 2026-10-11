import ArtCore

/// Knobs for `DatasetValidator`.
public struct ValidationOptions: Sendable {
    /// First day of the daily-challenge proof.
    public var dailyStart: DayKey
    /// Number of consecutive days that must generate cleanly (spec §15: 730).
    public var dailyDays: Int
    /// Daily rules version used for the proof.
    public var dailyRulesVersion: Int
    /// Independent single rounds generated per (round kind, difficulty) probe.
    public var probeRounds: Int
    /// Full standalone sessions generated per mode.
    public var probeSessions: Int
    /// Whether to open every image file and check its magic bytes.
    public var checkImageFiles: Bool
    /// Whether to run the (slower) generation probes: daily proof, round probes, session probes.
    public var runGenerationProbes: Bool

    public init(
        dailyStart: DayKey = DayKey(year: 2026, month: 10, day: 11), dailyDays: Int = 730,
        dailyRulesVersion: Int = DailyChallenge.currentRulesVersion, probeRounds: Int = 50, probeSessions: Int = 50,
        checkImageFiles: Bool = true, runGenerationProbes: Bool = true
    ) {
        self.dailyStart = dailyStart
        self.dailyDays = dailyDays
        self.dailyRulesVersion = dailyRulesVersion
        self.probeRounds = probeRounds
        self.probeSessions = probeSessions
        self.checkImageFiles = checkImageFiles
        self.runGenerationProbes = runGenerationProbes
    }
}
