import ArtCore

/// How serious a validation finding is.
public enum ValidationSeverity: String, Sendable, Codable, Comparable, CaseIterable {
    /// Informational; nothing to fix.
    case info
    /// Playable but degraded (thin content, fallbacks, missing optional metadata).
    case warning
    /// The app would crash, show broken content, or a mode would fail to generate.
    case error

    private var rank: Int {
        switch self {
        case .info: 0
        case .warning: 1
        case .error: 2
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
}

/// One validation finding. `code` is a stable machine-readable key used for grouping and tests.
public struct ValidationIssue: Sendable, Equatable, CustomStringConvertible {
    public var severity: ValidationSeverity
    public var code: String
    public var message: String
    /// The artwork concerned, if any.
    public var artworkID: ArtworkID?

    public init(_ severity: ValidationSeverity, _ code: String, _ message: String, artworkID: ArtworkID? = nil) {
        self.severity = severity
        self.code = code
        self.message = message
        self.artworkID = artworkID
    }

    public var description: String {
        let subject = artworkID.map { "[\($0)] " } ?? ""
        return "\(severity.rawValue.uppercased()) \(code): \(subject)\(message)"
    }
}
