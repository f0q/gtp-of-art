import ArtCore

/// A non-round line in `rounds.jsonl` recording the onboarding questionnaire, so a profile rebuilt
/// from history keeps the player's prior.
///
/// Line format (compact JSON, sorted keys, one per line):
/// ```
/// {"action":"complete","answers":{…OnboardingAnswers…},"kind":"onboarding","prior":{…TastePrior…},"recorded_at":1800000000}
/// {"action":"reset","kind":"onboarding","recorded_at":1800000100}
/// ```
/// Round lines have no `kind` key; any line whose `kind` is present is a non-round entry. Readers
/// skip (and report) kinds they do not know, so later entry kinds stay backward compatible.
/// On rebuild only the last onboarding entry matters: `complete` restores `prior`, seeds the taste
/// profile and sets `hasOnboarded`; `reset` clears all three.
public struct OnboardingLogEntry: Codable, Sendable, Equatable {
    public enum Action: String, Codable, Sendable {
        /// The questionnaire was answered (or skipped: `prior` nil).
        case complete
        /// "Redo questionnaire" in Settings.
        case reset
    }

    /// Value of the `kind` key for these lines.
    public static let kind = "onboarding"

    public var action: Action
    public var answers: OnboardingAnswers?
    public var prior: TastePrior?
    /// Unix time in seconds.
    public var recordedAt: Int64

    public init(action: Action, answers: OnboardingAnswers?, prior: TastePrior?, recordedAt: Int64) {
        self.action = action
        self.answers = answers
        self.prior = prior
        self.recordedAt = recordedAt
    }

    enum CodingKeys: String, CodingKey {
        case kind, action, answers, prior
        case recordedAt = "recorded_at"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        guard kind == Self.kind else {
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "kind \(kind)")
        }
        action = try c.decode(Action.self, forKey: .action)
        answers = try c.decodeIfPresent(OnboardingAnswers.self, forKey: .answers)
        prior = try c.decodeIfPresent(TastePrior.self, forKey: .prior)
        recordedAt = try c.decode(Int64.self, forKey: .recordedAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.kind, forKey: .kind)
        try c.encode(action, forKey: .action)
        try c.encodeIfPresent(answers, forKey: .answers)
        try c.encodeIfPresent(prior, forKey: .prior)
        try c.encode(recordedAt, forKey: .recordedAt)
    }
}

/// Peeks at a log line's `kind` (absent for round records).
struct LogLineKind: Decodable {
    var kind: String?
}
