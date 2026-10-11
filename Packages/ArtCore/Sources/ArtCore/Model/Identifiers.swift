/// Stable slug identifying an artwork, e.g. `"monet-water-lilies-1906"`. Encodes as a plain string.
public struct ArtworkID: RawRepresentable, Codable, Sendable, Hashable, Comparable,
    ExpressibleByStringLiteral, CustomStringConvertible
{
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { rawValue = value }
    public var description: String { rawValue }
    /// Ordered by UTF-8 bytes (see `utf8Less`).
    public static func < (lhs: Self, rhs: Self) -> Bool { utf8Less(lhs.rawValue, rhs.rawValue) }
}

/// Taxonomy category identifier, e.g. `"impressionism"`. Encodes as a plain string.
public struct CategoryID: RawRepresentable, Codable, Sendable, Hashable, Comparable,
    ExpressibleByStringLiteral, CustomStringConvertible
{
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { rawValue = value }
    public var description: String { rawValue }
    /// Ordered by UTF-8 bytes (see `utf8Less`).
    public static func < (lhs: Self, rhs: Self) -> Bool { utf8Less(lhs.rawValue, rhs.rawValue) }
}
