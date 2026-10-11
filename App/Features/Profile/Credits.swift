import ArtCore
import ArtData
import Foundation

/// `credits.json`: data sources, image credits and the price disclaimer.
nonisolated struct CreditsDocument: Decodable, Sendable, Equatable {
    struct DataSource: Decodable, Sendable, Equatable, Identifiable {
        var name: String
        var url: String
        var licence: String
        var id: String { name }
    }

    struct ImageCredit: Decodable, Sendable, Equatable, Identifiable {
        var artworkID: String
        var title: String
        var artist: String
        var licence: String
        var attribution: String
        var landingURL: String?
        var id: String { artworkID }

        enum CodingKeys: String, CodingKey {
            case artworkID = "artwork_id"
            case title, artist, licence, attribution
            case landingURL = "landing_url"
        }
    }

    var disclaimer: String
    var dataSources: [DataSource]
    var images: [ImageCredit]
    var copy: String?

    enum CodingKeys: String, CodingKey {
        case disclaimer
        case dataSources = "data_sources"
        case images, copy
    }

    static func load(bundle: Bundle = .main) -> CreditsDocument? {
        guard let url = bundle.url(forResource: "credits", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(CreditsDocument.self, from: data)
    }
}

/// The disclaimer stored at the top of `dataset.json` (not decoded by ArtCore's catalog).
nonisolated struct DatasetNotice: Decodable, Sendable, Equatable {
    var disclaimer: String

    static func load(bundle: Bundle = .main) -> DatasetNotice? {
        guard let url = bundle.url(forResource: "dataset", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(DatasetNotice.self, from: data)
    }
}
