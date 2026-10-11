import ArtCore

/// Everything `DatasetValidator` found, plus the measurements behind the generation findings.
public struct DatasetValidationReport: Sendable {
    /// `dataset_id`, if the file could be read.
    public var datasetVersion: String?
    /// Works in `dataset.json`.
    public var artworkCount = 0
    /// Works in the playable pool (status active).
    public var playableCount = 0
    /// Playable works with a usable game price.
    public var pricedCount = 0
    /// Playable works without one.
    public var unpricedCount = 0
    /// Image files opened and sniffed.
    public var imageFilesChecked = 0
    public var issues: [ValidationIssue] = []
    /// The 730-day daily proof (nil if generation probes were skipped or the data did not load).
    public var daily: DailyValidator.Report?
    public var roundProbes: [RoundProbeResult] = []
    public var sessionProbes: [SessionProbeResult] = []
    public var categoryCoverage: [CategoryCoverage] = []

    public init() {}

    public var errors: [ValidationIssue] { issues.filter { $0.severity == .error } }
    public var warnings: [ValidationIssue] { issues.filter { $0.severity == .warning } }

    /// True when there are no errors (warnings are allowed).
    public var isValid: Bool { errors.isEmpty }

    /// Issue counts per code for one severity, most frequent first (ties by code).
    public func counts(_ severity: ValidationSeverity) -> [(code: String, count: Int)] {
        var counts: [String: Int] = [:]
        for issue in issues where issue.severity == severity { counts[issue.code, default: 0] += 1 }
        return counts.map { (code: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.code < $1.code }
    }

    mutating func add(_ severity: ValidationSeverity, _ code: String, _ message: String, _ id: ArtworkID? = nil) {
        issues.append(ValidationIssue(severity, code, message, artworkID: id))
    }

    /// Multi-line human-readable summary: totals, issue counts by code, every error and warning,
    /// daily proof, and the generator/session tables.
    public var summary: String {
        var lines: [String] = []
        lines.append("Dataset \(datasetVersion ?? "?"): \(artworkCount) works, \(playableCount) playable "
            + "(\(pricedCount) priced, \(unpricedCount) unpriced), \(imageFilesChecked) image files checked")
        lines.append("Result: \(isValid ? "VALID" : "INVALID") — \(errors.count) errors, \(warnings.count) warnings")
        for severity in [ValidationSeverity.error, .warning] {
            let byCode = counts(severity)
            guard !byCode.isEmpty else { continue }
            lines.append("\(severity.rawValue)s by code: " + byCode.map { "\($0.code)×\($0.count)" }.joined(separator: ", "))
        }
        for issue in issues where issue.severity >= .warning { lines.append("  " + issue.description) }
        if let daily {
            lines.append("Daily: \(daily.daysChecked - Set(daily.failures.map(\.day)).count)/\(daily.daysChecked) days OK")
        }
        if !roundProbes.isEmpty {
            lines.append("Round probes (ok/attempts, capacity = no-repeat run, relaxed pairs):")
            for p in roundProbes {
                let fails = p.failures.sorted { $0.key < $1.key }.map { "\($0.key)×\($0.value)" }.joined(separator: " ")
                lines.append("  \(p.kind.rawValue).\(p.difficulty.rawValue): \(p.successes)/\(p.attempts)"
                    + " capacity \(p.capacity)" + (p.kind == .higherLower ? " relaxed \(p.relaxed)" : "")
                    + (fails.isEmpty ? "" : " failures: \(fails)"))
            }
        }
        if !sessionProbes.isEmpty {
            lines.append("Session probes:")
            for p in sessionProbes {
                let fails = p.failures.sorted { $0.key < $1.key }.map { "\($0.key)×\($0.value)" }.joined(separator: " ")
                lines.append("  \(p.mode.rawValue): \(p.successes)/\(p.attempts) (\(p.roundsPerSession) rounds)"
                    + (p.shortestPerfectRun.map { ", shortest perfect run \($0)" } ?? "")
                    + (fails.isEmpty ? "" : " failures: \(fails)"))
            }
        }
        let eligible = categoryCoverage.filter(\.quizEligible).map(\.id.rawValue)
        if !categoryCoverage.isEmpty {
            lines.append("Quiz-eligible categories: \(eligible.count)/\(categoryCoverage.filter(\.active).count) active"
                + (eligible.isEmpty ? "" : " (\(eligible.joined(separator: ", ")))"))
        }
        return lines.joined(separator: "\n")
    }
}
