import ArtCore
import Foundation

/// `{ "description": …, "cases": [ { "name", "input", "expected" } ] }`
public struct FixtureFile<Input: Codable & Sendable, Expected: Codable & Sendable>: Codable, Sendable {
    public var description: String
    public var cases: [FixtureCase<Input, Expected>]
    public init(description: String, cases: [FixtureCase<Input, Expected>]) {
        self.description = description
        self.cases = cases
    }
}

/// One named fixture case.
public struct FixtureCase<Input: Codable & Sendable, Expected: Codable & Sendable>: Codable, Sendable,
    CustomStringConvertible
{
    public var name: String
    public var input: Input
    public var expected: Expected
    public init(name: String, input: Input, expected: Expected) {
        self.name = name
        self.input = input
        self.expected = expected
    }
    public var description: String { name }
}

/// Reading and writing fixture JSON with a stable, diff-friendly format.
public enum FixtureIO {
    /// Pretty-printed, sorted keys, unescaped slashes.
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// `spec/fixtures` resolved from this source file's location.
    public static func defaultDirectory(filePath: String = #filePath) -> URL {
        // Packages/ArtCore/Sources/FixtureKit/FixtureIO.swift → repo root is 5 levels up.
        var url = URL(fileURLWithPath: filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url.appendingPathComponent("spec/fixtures", isDirectory: true)
    }

    public static func read<T: Decodable>(_ type: T.Type, named name: String, in directory: URL? = nil) throws -> T {
        let url = (directory ?? defaultDirectory()).appendingPathComponent(name)
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    public static func write<T: Encodable>(_ value: T, named name: String, in directory: URL) throws {
        var data = try makeEncoder().encode(value)
        data.append(0x0A)
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    /// Decimal string for a 64-bit unsigned value (fixtures avoid JSON numbers above 2^53).
    public static func u64(_ value: UInt64) -> String { String(value) }

    /// Parses a decimal (or `0x`-prefixed hex) 64-bit unsigned string.
    public static func u64(_ text: String) -> UInt64 {
        if text.hasPrefix("0x") { return UInt64(text.dropFirst(2), radix: 16)! }
        return UInt64(text)!
    }
}

/// `spec/fixtures/mini_dataset.json`: 30 synthetic works + taxonomy + taste baseline.
public struct MiniDataset: Codable, Sendable {
    public var schemaVersion: Int
    public var datasetID: String
    public var description: String
    public var artworks: [Artwork]
    public var taxonomy: [ArtCore.Category]
    public var departments: [Department]
    public var tasteBaseline: TasteBaseline
    public var disclaimer: String?
    public var refYear: Int?

    public init(
        schemaVersion: Int, datasetID: String, description: String, artworks: [Artwork],
        taxonomy: [ArtCore.Category], departments: [Department], tasteBaseline: TasteBaseline,
        disclaimer: String? = nil, refYear: Int? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.datasetID = datasetID
        self.description = description
        self.artworks = artworks
        self.taxonomy = taxonomy
        self.departments = departments
        self.disclaimer = disclaimer
        self.refYear = refYear
        self.tasteBaseline = tasteBaseline
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case datasetID = "dataset_id"
        case description, artworks, taxonomy, departments
        case tasteBaseline = "taste_baseline"
        case disclaimer
        case refYear = "ref_year"
    }

    public var pool: GamePool { GamePool(artworks: artworks, categories: taxonomy, departments: departments) }

    public static let fileName = "mini_dataset.json"

    public static func load(from directory: URL? = nil) throws -> MiniDataset {
        try FixtureIO.read(MiniDataset.self, named: fileName, in: directory)
    }
}
