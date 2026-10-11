import ArtCore
import ArtData
import Foundation

/// Every price string the app shows. All figures are 2 significant figures, marked approximate and
/// tied to a sale year (AGENTS.md rule 5). Pure, so unit-testable.
nonisolated enum PriceCopy {
    /// Option / bid label, e.g. "$2.0M".
    static func amount(_ usd: Int64) -> String {
        PriceFormatter.compactUSD(usd)
    }

    /// Year phrase used in questions: "in 2019", or "at its sale" when the year is unknown.
    static func yearPhrase(_ record: PriceRecord) -> String {
        record.saleYear.map { "in \($0)" } ?? "at its sale"
    }

    /// Pick-the-price / bid prompt.
    static func question(_ record: PriceRecord) -> String {
        "What did it sell for \(yearPhrase(record))?"
    }

    /// Verb for the provenance line.
    static func verb(_ type: PriceType) -> String {
        switch type {
        case .auctionPremium, .auctionHammer: "Sold"
        case .privateSale: "Sold privately"
        case .askPrice: "Offered"
        case .selfReported: "Priced"
        case .estimateLow, .estimateHigh: "Estimated"
        }
    }

    /// "Sold 2019 · Christie's London · approx. $2.0M incl. fees" (nominal USD).
    static func provenance(_ record: PriceRecord, showVenue: Bool) -> String {
        var parts = [verb(record.type) + (record.saleYear.map { " \($0)" } ?? "")]
        if showVenue, let venue = record.venue, !venue.isEmpty { parts.append(venue) }
        var price = "approx. " + PriceFormatter.compactUSD(record.usdNominal) + (record.lowerBound ? "+" : "")
        if let qualifier = PriceFormatter.qualifier(for: record.type, premiumIncluded: record.premiumIncluded) {
            price += " " + qualifier
        }
        parts.append(price)
        return parts.joined(separator: " · ")
    }

    /// Adjusted-basis line for "Which is pricier?": "≈$2.5M in 2025 dollars · sold 2019".
    static func adjusted(_ record: PriceRecord) -> String {
        let year = record.saleYear.map { " · sold \($0)" } ?? ""
        return "\(PriceFormatter.format(record, basis: .adjusted)) in \(record.adjustRefYear) dollars\(year)"
    }

    /// Second line under an adjusted price: "Sold 2019 for approx. $2.0M" (nominal).
    static func soldThen(_ record: PriceRecord) -> String {
        let year = record.saleYear.map { " \($0)" } ?? ""
        return "\(verb(record.type))\(year) for approx. \(PriceFormatter.compactUSD(record.usdNominal))"
            + (record.lowerBound ? "+" : "")
    }

    /// Locale for every number shown next to a price. `PriceFormatter` always writes "$2.8M" with
    /// a "." decimal, so ratios use the same convention to read consistently ("3.1×", not "3,1×").
    static let numberLocale = Locale(identifier: "en_US_POSIX")

    /// "3.1" / "12": one decimal below 10, none above.
    static func multiplier(_ factor: Double, locale: Locale = numberLocale) -> String {
        factor.formatted(.number.precision(.fractionLength(factor < 10 ? 1 : 0)).locale(locale))
    }

    /// "You were 3.1× under." / "You were spot on." (display-only Double; scoring stays integer).
    static func bidRatio(_ result: BidResult, locale: Locale = numberLocale) -> String {
        let factor = result.factor
        guard result.direction != .exact, factor >= 1.05 else { return "You were spot on." }
        return "You were \(multiplier(factor, locale: locale))× \(result.direction == .under ? "under" : "over")."
    }

    /// The original amount in its currency, e.g. "£1,571,250".
    static func original(_ record: PriceRecord) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = record.currency
        formatter.locale = Locale(identifier: "en_US")
        let digits = formatter.maximumFractionDigits
        var value = Decimal(record.amountMinor)
        for _ in 0..<digits { value /= 10 }
        formatter.maximumFractionDigits = value == value.rounded() ? 0 : digits
        return formatter.string(from: value as NSDecimalNumber) ?? "\(record.amountMinor) \(record.currency)"
    }

    /// What the price includes, for the ⓘ sheet.
    static func basisExplanation(_ record: PriceRecord) -> String {
        switch record.type {
        case .auctionPremium:
            "Auction price including the buyer's premium: the fee the auction house adds on top of the hammer price."
        case .auctionHammer:
            record.premiumIncluded == true
                ? "Auction price including the buyer's premium."
                : "Hammer price only: the winning bid before the buyer's premium was added."
        case .privateSale:
            "Private sale. The figure is as reported in the press and may be unconfirmed."
        case .askPrice:
            "Asking price. The work was offered at this figure; the final price may differ."
        case .selfReported:
            "Price set by the artist at the time."
        case .estimateLow, .estimateHigh:
            "Pre-sale estimate, not a sale price."
        }
    }
}

extension Decimal {
    nonisolated fileprivate func rounded() -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, 0, .plain)
        return result
    }
}

extension Artwork {
    /// The record named by `gamePriceID` even if not game-usable (for display only).
    nonisolated func price(id: String) -> PriceRecord? {
        prices.first { $0.id == id }
    }
}
