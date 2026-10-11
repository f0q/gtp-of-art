/// Auction-house style department id, e.g. `"old_masters"`. Encodes as a plain string and can key
/// a JSON object.
public struct DepartmentID: RawRepresentable, Codable, CodingKeyRepresentable, Sendable, Hashable, Comparable,
    ExpressibleByStringLiteral, CustomStringConvertible
{
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { rawValue = value }
    public var description: String { rawValue }
    /// Ordered by UTF-8 bytes (see `utf8Less`).
    public static func < (lhs: Self, rhs: Self) -> Bool { utf8Less(lhs.rawValue, rhs.rawValue) }

    public var codingKey: any CodingKey { DepartmentKey(stringValue: rawValue) }
    public init?<T: CodingKey>(codingKey: T) { rawValue = codingKey.stringValue }

    public static let oldMasters: DepartmentID = "old_masters"
    public static let nineteenthCentury: DepartmentID = "nineteenth_century"
    public static let impressionistModern: DepartmentID = "impressionist_modern"
    public static let asianArt: DepartmentID = "asian_art"
    public static let printsPhotographs: DepartmentID = "prints_photographs"
}

private struct DepartmentKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

/// A department (`taxonomy.json` → `departments[]`): the top level of the 2-level taxonomy and
/// the unit of a content pack.
public struct Department: Codable, Sendable, Equatable, Identifiable {
    public var id: DepartmentID
    public var label: String
    /// Member categories.
    public var categories: [CategoryID]

    public init(id: DepartmentID, label: String, categories: [CategoryID]) {
        self.id = id
        self.label = label
        self.categories = categories
    }

    /// Typical era buckets of the five standard departments, used to seed the taste profile from
    /// onboarding answers. Era-neutral departments (Asian art, prints & photographs) have none.
    public static let typicalEraBuckets: [DepartmentID: [String]] = [
        .oldMasters: ["pre1500", "1500_1600", "1600_1700", "1700_1800"],
        .nineteenthCentury: ["1800_1850", "1850_1900"],
        .impressionistModern: ["1850_1900", "1900_1930"],
        .asianArt: [],
        .printsPhotographs: [],
    ]
}
