import ArtCore

/// Supplies the population baseline used by the taste/rarity model.
///
/// Kept separate from `DatasetProviding` so phase 2 can swap the bundled synthetic baseline for
/// server population statistics with the same schema (plan D9).
public protocol TasteBaselineProviding: Sendable {
    /// The taste baseline (`taste_baseline.json`).
    var tasteBaseline: TasteBaseline { get }
}

/// Everything the game needs from the artwork dataset.
///
/// MVP: `BundledDataset` reads the files shipped in the app bundle. Phase 2 can add a
/// bundle + remote-delta implementation keyed by `datasetVersion` behind the same protocol.
public protocol DatasetProviding: TasteBaselineProviding {
    /// The dataset's `dataset_id`; part of the daily seed, so it must change whenever the content does.
    var datasetVersion: String { get }
    /// Decoded `dataset.json` (every work, including hidden/retired ones).
    var catalog: ArtworkCatalog { get }
    /// Taxonomy categories (`taxonomy.json`), sorted by id.
    var categories: [ArtCore.Category] { get }
    /// The playable pool: works with `status == active` plus the taxonomy, normalised by `GamePool`.
    var pool: GamePool { get }
    /// Resolves image file names to URLs and placeholder metadata.
    var images: ImageLocator { get }
    /// Onboarding exemplars (`onboarding.json`). Defaults to `.empty`.
    var onboarding: OnboardingCatalog { get }
}

extension DatasetProviding {
    /// Default for conformers that predate onboarding.
    public var onboarding: OnboardingCatalog { .empty }

    /// The price disclaimer (`dataset.json` → `disclaimer`), falling back to the plan's Part E10
    /// wording when the file has none.
    public var disclaimer: String {
        guard let text = catalog.disclaimer, !text.isEmpty else { return DatasetDisclaimer.fallback }
        return text
    }

    /// Year that inflation-adjusted prices are expressed in (`dataset.json` → `ref_year`); falls
    /// back to the latest `adjust_ref_year` of any price, then to 2025.
    public var refYear: Int {
        catalog.refYear ?? catalog.artworks.flatMap(\.prices).map(\.adjustRefYear).max() ?? 2025
    }

    /// Taxonomy departments, sorted by id.
    public var departments: [Department] { pool.departments }

    /// One bundled content pack per department, with playable/priced counts (sorted by id).
    public var contentPacks: [ContentPack] {
        let pool = self.pool
        return pool.departments.map { d in
            let ids = pool.artworkIDs(in: d.id)
            let priced = ids.filter { pool.artwork($0)?.gamePrice != nil }.count
            return ContentPack(department: d, artworkCount: ids.count, pricedCount: priced, state: .bundled)
        }
    }

    /// The department of a playable artwork.
    public func department(of id: ArtworkID) -> DepartmentID? { pool.department(of: id) }

    /// Playable works that have a usable game price (pick the price, bid, which is pricier).
    public var pricedArtworks: [Artwork] { pool.artworks.filter { $0.gamePrice != nil } }

    /// Playable works without a usable game price (swipe and category quiz only).
    public var unpricedArtworks: [Artwork] { pool.artworks.filter { $0.gamePrice == nil } }

    /// A playable artwork by id.
    public func artwork(_ id: ArtworkID) -> Artwork? { pool.artwork(id) }

    /// A taxonomy category by id.
    public func category(_ id: CategoryID) -> ArtCore.Category? { pool.category(id) }
}

/// Default wording for the price disclaimer (plan Part E10).
public enum DatasetDisclaimer {
    public static let fallback =
        "Prices are approximate public figures for historical sales, gathered from published reports, and are for "
        + "entertainment and education only. Auction prices usually include the buyer's premium; private-sale prices "
        + "are as reported and may be unconfirmed. Inflation-adjusted values are estimates. Nothing here is an "
        + "appraisal, valuation, or investment advice, and past sale prices do not indicate what any work would "
        + "fetch today."
}
