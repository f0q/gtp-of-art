import ArtCore

/// An artwork shown as an example of an onboarding choice.
public struct OnboardingExemplar: Codable, Sendable, Equatable {
    public var artworkID: ArtworkID
    /// Short caption (≤ 90 characters).
    public var caption: String

    public init(artworkID: ArtworkID, caption: String) {
        self.artworkID = artworkID
        self.caption = caption
    }

    enum CodingKeys: String, CodingKey {
        case artworkID = "artwork_id"
        case caption
    }
}

/// One selectable answer of the onboarding questionnaire (`onboarding.json` → `choices[]`).
///
/// Ids by step: 1 `classic | modern`; 2 a department id, optionally with a sub-choice
/// (`impressionist_modern:impressionist`); 3 `subject:landscape | people | still_life`;
/// 4 `mood:serene | dramatic`; 5 intent (no exemplars needed).
public struct OnboardingChoice: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    /// Questionnaire step 1…5.
    public var step: Int
    public var label: String
    public var exemplars: [OnboardingExemplar]

    public init(id: String, step: Int, label: String, exemplars: [OnboardingExemplar]) {
        self.id = id
        self.step = step
        self.label = label
        self.exemplars = exemplars
    }

    /// The part before `:` (`"impressionist_modern"` for `"impressionist_modern:avant_garde"`).
    public var baseID: String { String(id.split(separator: ":", maxSplits: 1).first ?? "") }

    /// The part after `:`, if any.
    public var qualifier: String? {
        let parts = id.split(separator: ":", maxSplits: 1)
        return parts.count == 2 ? String(parts[1]) : nil
    }

    /// Step 1: the era this choice selects.
    public var era: OnboardingAnswers.Era? { step == 1 ? OnboardingAnswers.Era(rawValue: id) : nil }
    /// Step 2: the department this choice selects.
    public var department: DepartmentID? { step == 2 ? DepartmentID(baseID) : nil }
    /// Step 3: the subject this choice selects.
    public var subject: OnboardingAnswers.Subject? {
        step == 3 && baseID == "subject" ? qualifier.flatMap(OnboardingAnswers.Subject.init(rawValue:)) : nil
    }
    /// Step 4: the mood this choice selects.
    public var mood: OnboardingAnswers.Mood? {
        step == 4 && baseID == "mood" ? qualifier.flatMap(OnboardingAnswers.Mood.init(rawValue:)) : nil
    }
}

/// `onboarding.json`: exemplar artworks for each questionnaire choice.
public struct OnboardingCatalog: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    /// Dataset the exemplars were picked from.
    public var datasetID: String?
    public var choices: [OnboardingChoice]

    public init(schemaVersion: Int = 1, datasetID: String? = nil, choices: [OnboardingChoice] = []) {
        self.schemaVersion = schemaVersion
        self.datasetID = datasetID
        self.choices = choices
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case datasetID = "dataset_id"
        case choices
    }

    /// An empty catalog (older bundles without `onboarding.json`).
    public static let empty = OnboardingCatalog()

    /// Choices of one step, in file order.
    public func choices(step: Int) -> [OnboardingChoice] { choices.filter { $0.step == step } }

    /// A choice by id.
    public func choice(_ id: String) -> OnboardingChoice? { choices.first { $0.id == id } }
}
