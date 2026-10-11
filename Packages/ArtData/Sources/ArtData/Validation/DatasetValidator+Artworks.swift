import ArtCore
import Foundation

extension DatasetValidator {
    /// Ids, slugs, prices, precomputed logs, game price resolution, taste ranges.
    static func checkArtworks(_ works: [Artwork], report: inout DatasetValidationReport) {
        var seenIDs = Set<ArtworkID>()
        var seenPriceIDs = Set<String>()
        for work in works {
            let id = work.id
            if !seenIDs.insert(id).inserted { report.add(.error, "duplicate_artwork_id", "id appears more than once", id) }
            if !isSlug(id.rawValue) { report.add(.warning, "id_not_slug", "id should be lowercase a-z, 0-9 and '-'", id) }
            if work.year == nil { report.add(.warning, "year_missing", "date has neither start nor end", id) }

            for price in work.prices {
                if !seenPriceIDs.insert(price.id).inserted {
                    report.add(.error, "duplicate_price_id", "price id \(price.id) is not unique", id)
                }
                checkLog(price.usdNominal, price.log10UsdNominalMilli, "\(price.id) nominal", id, &report)
                checkLog(price.usdAdjusted, price.log10UsdAdjustedMilli, "\(price.id) adjusted", id, &report)
            }

            if let gameID = work.gamePriceID {
                if let record = work.prices.first(where: { $0.id == gameID }) {
                    if !record.isUsableForGame {
                        report.add(.error, "game_price_ineligible",
                            "game_price_id \(gameID) is not usable (eligible \(record.gameEligible), type "
                            + "\(record.type.rawValue), scope \(record.priceScope.rawValue), confidence "
                            + "\(record.confidence.rawValue))", id)
                    } else if record.usdNominal < PriceOptionGenerator.minUSD || record.usdNominal > PriceOptionGenerator.maxUSD {
                        report.add(.warning, "price_outside_pick_band",
                            "usd_nominal \(record.usdNominal) is outside $500…$2B; not used by pick the price", id)
                    }
                } else {
                    report.add(.error, "game_price_unresolved", "game_price_id \(gameID) names no price record", id)
                }
            }

            let t = work.taste
            for (name, value) in [("abstraction", t.abstraction), ("warmth", t.warmth), ("saturation", t.saturation),
                ("brightness", t.brightness), ("complexity", t.complexity)] where !(0...100).contains(value)
            {
                report.add(.error, "taste_out_of_range", "taste.\(name) = \(value) is outside 0…100", id)
            }
            if let year = work.year, TasteFeatures.eraBucket(forYear: year) != t.eraBucket {
                report.add(.warning, "era_bucket_mismatch",
                    "taste.era_bucket \(t.eraBucket) but year \(year) → \(TasteFeatures.eraBucket(forYear: year))", id)
            }
        }
    }

    /// `log10_x_milli` must equal `floor(1000·log10(x) + 0.5)`. A value within 1e-6 of a rounding
    /// tie is a warning (pipeline and Foundation may round a tie differently); anything else an error.
    static func checkLog(_ usd: Int64, _ milli: Int, _ label: String, _ id: ArtworkID,
        _ report: inout DatasetValidationReport)
    {
        guard usd > 0 else {
            report.add(.error, "price_not_positive", "\(label) usd is \(usd)", id)
            return
        }
        let exact = 1000 * log10(Double(usd))
        let expected = Int((exact + 0.5).rounded(.down))
        guard expected != milli else { return }
        let nearTie = abs(exact - exact.rounded(.down) - 0.5) < 1e-6 && abs(expected - milli) == 1
        report.add(nearTie ? .warning : .error, "log10_mismatch",
            "\(label): log10 milli \(milli), expected \(expected) for $\(usd)", id)
    }

    static func isSlug(_ s: String) -> Bool {
        !s.isEmpty && s.utf8.allSatisfy { b in
            (b >= UInt8(ascii: "a") && b <= UInt8(ascii: "z")) || (b >= UInt8(ascii: "0") && b <= UInt8(ascii: "9"))
                || b == UInt8(ascii: "-")
        }
    }

    /// Every primary/secondary category exists; primary categories should be active.
    static func checkCategoryReferences(_ works: [Artwork], taxonomy: Taxonomy, report: inout DatasetValidationReport) {
        let byID = Dictionary(taxonomy.categories.map { ($0.id, $0) }) { first, _ in first }
        for work in works {
            if let primary = byID[work.category] {
                if !primary.active {
                    report.add(.warning, "inactive_primary_category", "category \(work.category) is inactive", work.id)
                }
            } else {
                report.add(.error, "unknown_category", "category_id \(work.category) is not in the taxonomy", work.id)
            }
            for secondary in work.acceptedAlso {
                if byID[secondary] == nil {
                    report.add(.error, "unknown_category",
                        "secondary_category_ids has \(secondary), not in the taxonomy", work.id)
                }
                if secondary == work.category {
                    report.add(.warning, "secondary_repeats_primary", "secondary list repeats \(secondary)", work.id)
                }
            }
        }
    }

    /// Unique ids, valid eras, and parent/neighbour/confuser references that resolve.
    static func checkTaxonomy(_ taxonomy: Taxonomy, report: inout DatasetValidationReport) {
        var ids = Set<CategoryID>()
        for c in taxonomy.categories where !ids.insert(c.id).inserted {
            report.add(.error, "duplicate_category_id", "taxonomy id \(c.id) appears more than once")
        }
        for c in taxonomy.categories {
            if c.era.start > c.era.end { report.add(.error, "category_era_inverted", "\(c.id) era start > end") }
            if c.minQuizItems < 1 { report.add(.warning, "category_min_quiz_items", "\(c.id) min_quiz_items < 1") }
            let refs = (c.parent.map { [$0] } ?? []) + c.neighbours + c.confusers
            for ref in refs where !ids.contains(ref) {
                report.add(.error, "unknown_category_reference", "\(c.id) references unknown category \(ref)")
            }
        }
    }

    /// Baseline sanity: like-rates in (0, 1), alpha positive, archetype shares sum to ~1.
    static func checkBaseline(_ baseline: TasteBaseline, report: inout DatasetValidationReport) {
        for (key, value) in baseline.features.sorted(by: { $0.key < $1.key }) where !(value.pLike > 0 && value.pLike < 1) {
            report.add(.warning, "baseline_p_like_range", "\(key) p_like \(value.pLike) is not in (0, 1)")
        }
        if baseline.alpha <= 0 { report.add(.error, "baseline_alpha", "alpha must be positive") }
        if baseline.swipeBuckets.isEmpty {
            report.add(.error, "baseline_percentiles_missing", "no swipes_N distinctiveness tables")
        }
        let shareSum = baseline.archetypeShares.values.reduce(0, +)
        if abs(shareSum - 1) > 0.01 {
            report.add(.warning, "baseline_archetype_shares", "archetype shares sum to \(shareSum), not 1")
        }
    }

    /// Every taste bucket of every work should have a baseline entry; a missing one is ignored by
    /// the lift model (no crash) but weakens the profile, so it is a warning with the work count.
    static func checkTasteBuckets(_ works: [Artwork], baseline: TasteBaseline, report: inout DatasetValidationReport) {
        var missing: [String: Int] = [:]
        for work in works {
            for bucket in TasteBuckets.buckets(for: work) where baseline.features[bucket] == nil {
                missing[bucket, default: 0] += 1
            }
        }
        for (bucket, count) in missing.sorted(by: { $0.key < $1.key }) {
            report.add(.warning, "taste_bucket_missing", "baseline has no \(bucket) (used by \(count) works)")
        }
    }
}
