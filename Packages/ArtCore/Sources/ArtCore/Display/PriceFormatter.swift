/// Which USD figure a price display uses (Part E8: pick/bid nominal with year; pricier adjusted).
public enum PriceBasis: String, Codable, Sendable {
    case nominal, adjusted
}

/// Price display strings: 2 significant figures + K/M/B suffix, with honesty markers.
///
/// Markers: `~` prefix for reported private sales; otherwise `≈` prefix when approximate or
/// FX-converted (and always for inflation-adjusted figures); `+` suffix for lower bounds.
/// Examples: `$450M`, `$2.8M`, `$57K`, `$850`, `≈$5.5M`, `~$250M+`.
public enum PriceFormatter {
    /// `$` + 2-s.f. compact value. Suffix chosen after rounding: <1,000 none, <1M "K", <1B "M", else "B".
    public static func compactUSD(_ usd: Int64) -> String {
        let r = SigFig.round2(max(0, usd))
        let (unit, suffix): (Int64, String) =
            r >= 1_000_000_000 ? (1_000_000_000, "B") : r >= 1_000_000 ? (1_000_000, "M") : r >= 1000 ? (1000, "K") : (1, "")
        let whole = r / unit
        let tenth = (r % unit) * 10 / unit
        return "$" + String(whole) + (tenth != 0 ? "." + String(tenth) : "") + suffix
    }

    /// Full display string with markers.
    public static func format(usd: Int64, approximate: Bool, reported: Bool, lowerBound: Bool) -> String {
        let prefix = reported ? "~" : (approximate ? "≈" : "")
        return prefix + compactUSD(usd) + (lowerBound ? "+" : "")
    }

    /// Formats a record on the given basis. Reported = private sale; approximate = flagged
    /// approximate, non-USD original, or adjusted basis.
    public static func format(_ record: PriceRecord, basis: PriceBasis) -> String {
        let usd = basis == .nominal ? record.usdNominal : record.usdAdjusted
        let approximate = record.approximate || record.currency != "USD" || basis == .adjusted
        return format(
            usd: usd, approximate: approximate, reported: record.type == .privateSale, lowerBound: record.lowerBound)
    }

    /// Short qualifier for the price type, shown next to the figure; nil when none is needed.
    public static func qualifier(for type: PriceType, premiumIncluded: Bool?) -> String? {
        switch type {
        case .auctionPremium: "incl. fees"
        case .auctionHammer: premiumIncluded == true ? "incl. fees" : "hammer"
        case .privateSale: "reported"
        case .askPrice: "asking"
        case .selfReported: "artist's price"
        case .estimateLow, .estimateHigh: "estimate"
        }
    }
}
