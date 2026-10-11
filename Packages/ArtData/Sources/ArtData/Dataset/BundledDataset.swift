import ArtCore
import Foundation

/// The dataset shipped with the app: `dataset.json`, `taxonomy.json`, `taste_baseline.json` and
/// the `Artworks/` images, decoded once into ArtCore types.
///
/// Decoding uses a plain `JSONDecoder`: ArtCore types carry explicit snake_case coding keys, so no
/// key strategy is set. Unknown JSON keys are ignored.
public struct BundledDataset: DatasetProviding {
    public let datasetVersion: String
    public let catalog: ArtworkCatalog
    public let categories: [ArtCore.Category]
    public let pool: GamePool
    public let tasteBaseline: TasteBaseline
    public let images: ImageLocator
    public let onboarding: OnboardingCatalog
    /// Status of every work in the file (absent status counts as active).
    public let statuses: [ArtworkID: ArtworkStatus]

    /// Loads from a resources directory laid out like the app bundle (JSON files at the root,
    /// including the optional `onboarding.json`; images in `Artworks/` unless `imagesDirectory`
    /// is given).
    public init(resourcesDirectory: URL, imagesDirectory: URL? = nil) throws {
        let catalogData = try Self.read(DatasetFiles.dataset, in: resourcesDirectory)
        let catalog = try Self.decode(ArtworkCatalog.self, from: catalogData, file: DatasetFiles.dataset)
        let statusFile = try Self.decode(ArtworkStatusFile.self, from: catalogData, file: DatasetFiles.dataset)
        let taxonomy = try Self.decode(
            Taxonomy.self, from: try Self.read(DatasetFiles.taxonomy, in: resourcesDirectory),
            file: DatasetFiles.taxonomy)
        let baseline = try Self.decode(
            TasteBaseline.self, from: try Self.read(DatasetFiles.tasteBaseline, in: resourcesDirectory),
            file: DatasetFiles.tasteBaseline)
        // onboarding.json is optional (older bundles); if present it must decode.
        var onboarding = OnboardingCatalog.empty
        if let data = try? Data(contentsOf: resourcesDirectory.appendingPathComponent(DatasetFiles.onboarding)) {
            onboarding = try Self.decode(OnboardingCatalog.self, from: data, file: DatasetFiles.onboarding)
        }
        self.init(
            catalog: catalog, taxonomy: taxonomy, tasteBaseline: baseline,
            statuses: Dictionary(statusFile.artworks.map { ($0.id, $0.status ?? .active) }) { first, _ in first },
            images: ImageLocator(directory: imagesDirectory ?? DatasetFiles.artworksDirectory(in: resourcesDirectory)),
            onboarding: onboarding)
    }

    /// Loads from an app bundle: JSON at the resource root, images in the `Artworks` folder reference.
    public init(bundle: Bundle) throws {
        guard let resources = bundle.resourceURL else { throw DatasetLoadError.missingResourceDirectory }
        try self.init(resourcesDirectory: resources)
    }

    /// Builds a dataset from already-decoded parts (previews, tests).
    /// Works whose status is not `active` are left out of `pool`.
    public init(
        catalog: ArtworkCatalog, taxonomy: Taxonomy, tasteBaseline: TasteBaseline,
        statuses: [ArtworkID: ArtworkStatus] = [:], images: ImageLocator, onboarding: OnboardingCatalog = .empty
    ) {
        datasetVersion = catalog.datasetID
        self.catalog = catalog
        self.tasteBaseline = tasteBaseline
        self.statuses = statuses
        self.images = images
        self.onboarding = onboarding
        let playable = catalog.artworks.filter { (statuses[$0.id] ?? .active) == .active }
        pool = GamePool(artworks: playable, categories: taxonomy.categories, departments: taxonomy.departments)
        categories = pool.categories
    }

    static func read(_ name: String, in directory: URL) throws -> Data {
        let url = directory.appendingPathComponent(name, isDirectory: false)
        do {
            return try Data(contentsOf: url)
        } catch {
            throw DatasetLoadError.unreadable(file: name, underlying: error.localizedDescription)
        }
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data, file: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw DatasetLoadError.undecodable(file: file, underlying: String(describing: error))
        }
    }
}
