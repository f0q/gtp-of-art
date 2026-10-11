/// Artist reference (`artworks[].artist`).
public struct ArtistRef: Codable, Sendable, Equatable {
    public var id: String?
    public var displayName: String
    public var birthYear: Int?
    public var deathYear: Int?
    public var nationality: String?

    public init(id: String?, displayName: String, birthYear: Int?, deathYear: Int?, nationality: String?) {
        self.id = id
        self.displayName = displayName
        self.birthYear = birthYear
        self.deathYear = deathYear
        self.nationality = nationality
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case birthYear = "birth_year"
        case deathYear = "death_year"
        case nationality
    }
}

/// Creation date (`artworks[].date`).
public struct ArtworkDate: Codable, Sendable, Equatable {
    /// Human label, e.g. `"c. 1500"`.
    public var display: String
    public var start: Int?
    public var end: Int?
    public var circa: Bool?

    public init(display: String, start: Int?, end: Int?, circa: Bool?) {
        self.display = display
        self.start = start
        self.end = end
        self.circa = circa
    }
}

/// Medium (`artworks[].medium`).
public struct Medium: Codable, Sendable, Equatable {
    public var display: String
    /// `painting | drawing | print | photograph | sculpture`.
    public var mediumClass: String

    public init(display: String, mediumClass: String) {
        self.display = display
        self.mediumClass = mediumClass
    }

    enum CodingKeys: String, CodingKey {
        case display
        case mediumClass = "medium_class"
    }
}

/// One image rendition file.
public struct ImageFile: Codable, Sendable, Equatable {
    public var file: String
    public var w: Int
    public var h: Int
    public var bytes: Int?

    public init(file: String, w: Int, h: Int, bytes: Int?) {
        self.file = file
        self.w = w
        self.h = h
        self.bytes = bytes
    }
}

/// Point of interest in permille of width/height (0…1000), used for zooms and crops.
public struct FocusPoint: Codable, Sendable, Equatable {
    public var x: Int
    public var y: Int
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

/// Image reference with rights metadata (`artworks[].images.primary`).
public struct ImageRef: Codable, Sendable, Equatable {
    public var sm: ImageFile?
    public var lg: ImageFile?
    public var sourceURL: String?
    public var landingURL: String?
    public var licence: String
    public var attribution: String
    public var depictsScope: String?
    public var altText: String
    public var focus: FocusPoint
    /// `"#RRGGBB"` placeholder colour.
    public var dominantHex: String
    /// Up to five `"#RRGGBB"` palette colours (JSON `palette`); nil if absent.
    public var palette: [String]?

    public init(
        sm: ImageFile?, lg: ImageFile?, sourceURL: String?, landingURL: String?, licence: String,
        attribution: String, depictsScope: String?, altText: String, focus: FocusPoint, dominantHex: String,
        palette: [String]? = nil
    ) {
        self.sm = sm
        self.lg = lg
        self.sourceURL = sourceURL
        self.landingURL = landingURL
        self.licence = licence
        self.attribution = attribution
        self.depictsScope = depictsScope
        self.altText = altText
        self.focus = focus
        self.dominantHex = dominantHex
        self.palette = palette
    }

    enum CodingKeys: String, CodingKey {
        case sm, lg
        case sourceURL = "source_url"
        case landingURL = "landing_url"
        case licence, attribution
        case depictsScope = "depicts_scope"
        case altText = "alt_text"
        case focus
        case dominantHex = "dominant_hex"
        case palette
    }
}

/// Image set (`artworks[].images`).
public struct ArtworkImages: Codable, Sendable, Equatable {
    public var primary: ImageRef
    public init(primary: ImageRef) { self.primary = primary }
}

/// An artwork in the bundled dataset. Unknown JSON keys are ignored.
public struct Artwork: Codable, Sendable, Equatable, Identifiable {
    public var id: ArtworkID
    /// `pd_masterpiece | contemporary_listing | user_upload`.
    public var kind: String?
    public var title: String
    public var artist: ArtistRef
    public var date: ArtworkDate
    /// Primary category (JSON `category_id`).
    public var category: CategoryID
    /// Categories also accepted as correct (JSON `secondary_category_ids`).
    public var acceptedAlso: [CategoryID]
    public var medium: Medium
    public var images: ArtworkImages
    public var prices: [PriceRecord]
    /// The price used by game modes (JSON `game_price_id`); nil for unpriced works.
    public var gamePriceID: String?
    public var taste: TasteFeatures
    /// Optional explicit department (JSON `department_id`); normally resolved from the primary
    /// category via `GamePool.department(of:)`.
    public var departmentID: DepartmentID?

    public init(
        id: ArtworkID, kind: String?, title: String, artist: ArtistRef, date: ArtworkDate,
        category: CategoryID, acceptedAlso: [CategoryID], medium: Medium, images: ArtworkImages,
        prices: [PriceRecord], gamePriceID: String?, taste: TasteFeatures, departmentID: DepartmentID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.artist = artist
        self.date = date
        self.category = category
        self.acceptedAlso = acceptedAlso
        self.medium = medium
        self.images = images
        self.prices = prices
        self.gamePriceID = gamePriceID
        self.taste = taste
        self.departmentID = departmentID
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, title, artist, date
        case category = "category_id"
        case acceptedAlso = "secondary_category_ids"
        case medium, images, prices
        case gamePriceID = "game_price_id"
        case taste
        case departmentID = "department_id"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ArtworkID.self, forKey: .id)
        kind = try c.decodeIfPresent(String.self, forKey: .kind)
        title = try c.decode(String.self, forKey: .title)
        artist = try c.decode(ArtistRef.self, forKey: .artist)
        date = try c.decode(ArtworkDate.self, forKey: .date)
        category = try c.decode(CategoryID.self, forKey: .category)
        acceptedAlso = try c.decodeIfPresent([CategoryID].self, forKey: .acceptedAlso) ?? []
        medium = try c.decode(Medium.self, forKey: .medium)
        images = try c.decode(ArtworkImages.self, forKey: .images)
        prices = try c.decodeIfPresent([PriceRecord].self, forKey: .prices) ?? []
        gamePriceID = try c.decodeIfPresent(String.self, forKey: .gamePriceID)
        taste = try c.decode(TasteFeatures.self, forKey: .taste)
        departmentID = try c.decodeIfPresent(DepartmentID.self, forKey: .departmentID)
    }

    /// The primary image.
    public var image: ImageRef { images.primary }

    /// The record named by `gamePriceID` if it is usable for games (`PriceRecord.isUsableForGame`).
    public var gamePrice: PriceRecord? {
        guard let gamePriceID else { return nil }
        guard let record = prices.first(where: { $0.id == gamePriceID }), record.isUsableForGame else {
            return nil
        }
        return record
    }

    /// Creation year used for era comparisons (`date.start`, else `date.end`).
    public var year: Int? { date.start ?? date.end }

    /// Primary category followed by accepted alternates, without duplicates.
    public var allCategories: [CategoryID] {
        var result = [category]
        for c in acceptedAlso where !result.contains(c) {
            result.append(c)
        }
        return result
    }
}
