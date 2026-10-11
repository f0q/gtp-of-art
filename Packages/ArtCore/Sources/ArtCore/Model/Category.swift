/// Whether a category is an art-historical movement or a medium.
public enum CategoryAxis: String, Codable, Sendable, CaseIterable {
    case movement
    case medium
}

/// Inclusive year range.
public struct EraRange: Codable, Sendable, Equatable {
    public var start: Int
    public var end: Int
    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    /// Years between two ranges: 0 if they overlap, else the distance between the nearest ends.
    public func gap(to other: EraRange) -> Int {
        max(0, max(start, other.start) - min(end, other.end))
    }
}

/// A taxonomy entry (`taxonomy.json` → `categories[]`).
public struct Category: Codable, Sendable, Equatable, Identifiable {
    public var id: CategoryID
    public var label: String
    public var axis: CategoryAxis
    public var era: EraRange
    public var parent: CategoryID?
    /// One-line teaching sentence shown on reveal.
    public var teach: String
    /// Three visual tells.
    public var tells: [String]
    public var neighbours: [CategoryID]
    public var confusers: [CategoryID]
    /// Minimum number of works (primary category) required before the category is quizzed.
    public var minQuizItems: Int
    public var active: Bool
    /// Department this category belongs to (JSON `department_id`); nil for unassigned/inactive ones.
    public var departmentID: DepartmentID?

    public init(
        id: CategoryID, label: String, axis: CategoryAxis, era: EraRange, parent: CategoryID?,
        teach: String, tells: [String], neighbours: [CategoryID], confusers: [CategoryID],
        minQuizItems: Int, active: Bool, departmentID: DepartmentID? = nil
    ) {
        self.id = id
        self.label = label
        self.axis = axis
        self.era = era
        self.parent = parent
        self.teach = teach
        self.tells = tells
        self.neighbours = neighbours
        self.confusers = confusers
        self.minQuizItems = minQuizItems
        self.active = active
        self.departmentID = departmentID
    }

    enum CodingKeys: String, CodingKey {
        case id, label, axis, era, parent, teach, tells, neighbours, confusers
        case minQuizItems = "min_quiz_items"
        case active
        case departmentID = "department_id"
    }
}
