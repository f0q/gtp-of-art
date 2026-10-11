/// Answers to the onboarding questionnaire (plan Part I2). Every step is skippable (nil / empty).
public struct OnboardingAnswers: Codable, Sendable, Equatable {
    /// Step 1: "Which world draws you in?"
    public enum Era: String, Codable, Sendable, CaseIterable {
        case classic, modern

        /// Departments implied by the era when step 2 was skipped.
        public var departments: [DepartmentID] {
            switch self {
            case .classic: [.oldMasters, .nineteenthCentury]
            case .modern: [.impressionistModern]
            }
        }
    }

    /// Step 3: "What do you like to look at?"
    public enum Subject: String, Codable, Sendable, CaseIterable {
        case landscape
        case people
        case stillLife = "still_life"

        /// Taste-feature subjects (`TasteFeatures.subject`) this choice covers.
        public var tasteSubjects: [String] {
            switch self {
            case .landscape: ["landscape"]
            case .people: ["portrait", "figure", "genre"]
            case .stillLife: ["still_life"]
            }
        }
    }

    /// Step 4: "Which mood?"
    public enum Mood: String, Codable, Sendable, CaseIterable {
        case serene, dramatic

        /// Taste-feature moods this choice covers (the sign of the Mood axis).
        public var tasteMoods: [String] {
            switch self {
            case .serene: ["serene", "joyful"]
            case .dramatic: ["dramatic", "melancholic"]
            }
        }
    }

    /// Step 5: "Why are you here?"
    public enum Intent: String, Codable, Sendable, CaseIterable {
        case learn, play
        case testMyEye = "test_my_eye"
    }

    public var era: Era?
    /// Step 2 (multi-select).
    public var departments: Set<DepartmentID>
    public var subjects: Set<Subject>
    public var mood: Mood?
    public var intent: Intent?

    public init(
        era: Era? = nil, departments: Set<DepartmentID> = [], subjects: Set<Subject> = [], mood: Mood? = nil,
        intent: Intent? = nil
    ) {
        self.era = era
        self.departments = departments
        self.subjects = subjects
        self.mood = mood
        self.intent = intent
    }

    enum CodingKeys: String, CodingKey { case era, departments, subjects, mood, intent }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        era = try c.decodeIfPresent(Era.self, forKey: .era)
        departments = Set(try c.decodeIfPresent([DepartmentID].self, forKey: .departments) ?? [])
        subjects = Set(try c.decodeIfPresent([Subject].self, forKey: .subjects) ?? [])
        mood = try c.decodeIfPresent(Mood.self, forKey: .mood)
        intent = try c.decodeIfPresent(Intent.self, forKey: .intent)
    }

    /// Sets encode as arrays sorted by raw value, so the JSON is deterministic.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(era, forKey: .era)
        try c.encode(departments.sorted(), forKey: .departments)
        try c.encode(subjects.sorted { utf8Less($0.rawValue, $1.rawValue) }, forKey: .subjects)
        try c.encodeIfPresent(mood, forKey: .mood)
        try c.encodeIfPresent(intent, forKey: .intent)
    }
}
