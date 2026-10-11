import ArtCore
import Foundation

/// Checks a dataset directory end to end: decoding, references, image files, precomputed logs,
/// taste buckets, departments, onboarding exemplars, the 730-day daily proof and generator capacity.
///
/// Runs in tests (`DatasetValidatorTests`) and can be called from the app in DEBUG builds:
/// `DatasetValidator.validate(bundle: .main)`. Severity policy:
/// - **error**: the app would crash or show broken content, or a mode/day would fail to generate.
/// - **warning**: playable but degraded (thin categories, relaxed pairs, missing baseline buckets,
///   metadata mismatches, fallbacks).
/// - **info**: counts worth knowing.
public enum DatasetValidator {
    /// Validates the dataset in an app bundle (JSON at the resource root, images in `Artworks/`).
    public static func validate(bundle: Bundle, options: ValidationOptions = ValidationOptions())
        -> DatasetValidationReport
    {
        guard let resources = bundle.resourceURL else {
            var report = DatasetValidationReport()
            report.add(.error, "bundle_without_resources", "bundle has no resource directory")
            return report
        }
        return validate(resourcesDirectory: resources, options: options)
    }

    /// Validates `dataset.json`, `taxonomy.json`, `taste_baseline.json` in `resourcesDirectory`
    /// and the images in `imagesDirectory` (default `resourcesDirectory/Artworks`).
    public static func validate(
        resourcesDirectory: URL, imagesDirectory: URL? = nil, options: ValidationOptions = ValidationOptions()
    ) -> DatasetValidationReport {
        var report = DatasetValidationReport()
        let images = ImageLocator(directory: imagesDirectory ?? DatasetFiles.artworksDirectory(in: resourcesDirectory))

        // 1. Decode the three files, each artwork individually so one bad record is pinpointed.
        let artworks = decodeArtworks(in: resourcesDirectory, report: &report)
        let taxonomy: Taxonomy? = decodeFile(DatasetFiles.taxonomy, in: resourcesDirectory, report: &report)
        let baseline: TasteBaseline? = decodeFile(DatasetFiles.tasteBaseline, in: resourcesDirectory, report: &report)
        guard let artworks else { return report }

        // 2. Static checks.
        checkArtworks(artworks.works, report: &report)
        if let taxonomy {
            checkTaxonomy(taxonomy, report: &report)
            checkCategoryReferences(artworks.works, taxonomy: taxonomy, report: &report)
        }
        if let baseline {
            checkBaseline(baseline, report: &report)
            checkTasteBuckets(artworks.works, baseline: baseline, report: &report)
        }
        checkImages(artworks.works, locator: images, checkFiles: options.checkImageFiles, report: &report)

        // 3. Generation checks on the playable pool.
        guard let taxonomy, let datasetVersion = report.datasetVersion else { return report }
        let playable = artworks.works.filter { (artworks.statuses[$0.id] ?? .active) == .active }
        let pool = GamePool(artworks: playable, categories: taxonomy.categories, departments: taxonomy.departments)
        checkDepartments(pool: pool, taxonomy: taxonomy, report: &report)
        checkOnboarding(in: resourcesDirectory, pool: pool, locator: images, checkFiles: options.checkImageFiles,
            report: &report)
        report.playableCount = pool.artworks.count
        report.pricedCount = pool.artworks.filter { $0.gamePrice != nil }.count
        report.unpricedCount = report.playableCount - report.pricedCount
        report.add(.info, "pool_size", "\(report.playableCount) playable works: \(report.pricedCount) priced, "
            + "\(report.unpricedCount) unpriced")
        checkCategoryCoverage(pool: pool, report: &report)
        if options.runGenerationProbes {
            checkGeneration(pool: pool, datasetVersion: datasetVersion, options: options, report: &report)
        }
        return report
    }

    // MARK: - Decoding

    struct DecodedArtworks {
        var works: [Artwork]
        var statuses: [ArtworkID: ArtworkStatus]
    }

    static func decodeArtworks(in directory: URL, report: inout DatasetValidationReport) -> DecodedArtworks? {
        let file = DatasetFiles.dataset
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(file)) else {
            report.add(.error, "file_unreadable", "\(file) is missing or unreadable")
            return nil
        }
        guard let top = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let rawWorks = top["artworks"] as? [Any]
        else {
            report.add(.error, "file_undecodable", "\(file) is not a JSON object with an artworks array")
            return nil
        }
        report.datasetVersion = top["dataset_id"] as? String
        if report.datasetVersion?.isEmpty ?? true {
            report.add(.error, "dataset_id_missing", "\(file) has no dataset_id (needed for the daily seed)")
        }
        report.artworkCount = rawWorks.count
        do {
            _ = try JSONDecoder().decode(ArtworkCatalog.self, from: data)
        } catch {
            report.add(.error, "catalog_undecodable", "ArtworkCatalog does not decode: \(error)")
        }
        var works: [Artwork] = []
        var statuses: [ArtworkID: ArtworkStatus] = [:]
        for (index, raw) in rawWorks.enumerated() {
            let rawID = (raw as? [String: Any])?["id"] as? String
            let label = rawID.map { ArtworkID($0) }
            do {
                let itemData = try JSONSerialization.data(withJSONObject: raw)
                let work = try JSONDecoder().decode(Artwork.self, from: itemData)
                works.append(work)
                if let status = try JSONDecoder().decode(ArtworkStatusEntry.self, from: itemData).status {
                    statuses[work.id] = status
                }
            } catch {
                report.add(.error, "artwork_undecodable", "artworks[\(index)] does not decode: \(error)", label)
            }
        }
        return DecodedArtworks(works: works, statuses: statuses)
    }

    static func decodeFile<T: Decodable>(_ file: String, in directory: URL, report: inout DatasetValidationReport)
        -> T?
    {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(file)) else {
            report.add(.error, "file_unreadable", "\(file) is missing or unreadable")
            return nil
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            report.add(.error, "file_undecodable", "\(file) does not decode: \(error)")
            return nil
        }
    }
}
