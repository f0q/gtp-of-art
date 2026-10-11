/// Top level of `dataset.json`.
public struct ArtworkCatalog: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    /// Dataset identity; also the `datasetVersion` that feeds the daily seed.
    public var datasetID: String
    public var artworks: [Artwork]
    /// Price disclaimer shown in Settings/Credits (JSON `disclaimer`); nil if absent.
    public var disclaimer: String?
    /// Year that `usd_adjusted` values are expressed in (JSON `ref_year`); nil if absent.
    public var refYear: Int?

    public init(
        schemaVersion: Int, datasetID: String, artworks: [Artwork], disclaimer: String? = nil, refYear: Int? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.datasetID = datasetID
        self.artworks = artworks
        self.disclaimer = disclaimer
        self.refYear = refYear
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case datasetID = "dataset_id"
        case artworks, disclaimer
        case refYear = "ref_year"
    }
}

/// Top level of `taxonomy.json`.
public struct Taxonomy: Codable, Sendable, Equatable {
    public var categories: [Category]
    /// Departments (missing in older files → empty).
    public var departments: [Department]

    public init(categories: [Category]) {
        self.init(categories: categories, departments: [])
    }

    public init(categories: [Category], departments: [Department]) {
        self.categories = categories
        self.departments = departments
    }

    enum CodingKeys: String, CodingKey { case categories, departments }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categories = try c.decode([Category].self, forKey: .categories)
        departments = try c.decodeIfPresent([Department].self, forKey: .departments) ?? []
    }
}
