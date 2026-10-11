import ArtCore
import ArtData
import Foundation

/// A tile on the hub's mode grid.
struct ModeTileInfo: Identifiable, Equatable {
    let mode: GameMode
    let title: String
    let blurb: String
    let symbol: String
    let isAvailable: Bool
    var id: GameMode { mode }
}

/// Pure hub content: Painting of the Day, daily numbering and the mode tiles (unit-tested).
enum HomeContent {
    /// The first day of the daily challenge ("Day 1").
    static let launchDay = DayKey(year: 2026, month: 10, day: 12)

    static let tiles: [ModeTileInfo] = [
        ModeTileInfo(mode: .pickPrice, title: "Pick the price", blurb: "Four estimates, one hammer price.",
                     symbol: "tag", isAvailable: true),
        ModeTileInfo(mode: .higherLower, title: "Which is pricier?", blurb: "Two works. Trust your eye.",
                     symbol: "arrow.up.arrow.down", isAvailable: true),
        ModeTileInfo(mode: .bid, title: "Bid", blurb: "Name your price on the log scale.",
                     symbol: "hammer", isAvailable: true),
        ModeTileInfo(mode: .category, title: "Category quiz", blurb: "Name the movement.",
                     symbol: "square.grid.2x2", isAvailable: true),
        ModeTileInfo(mode: .swipe, title: "Swipe", blurb: "Keep or pass. Find your taste.",
                     symbol: "rectangle.stack", isAvailable: true),
    ]

    static func tile(for mode: GameMode) -> ModeTileInfo? {
        tiles.first { $0.mode == mode }
    }

    /// Deterministic Painting of the Day: a priced work chosen by a SplitMix64 step of the day number.
    static func paintingOfTheDay(on day: DayKey, dataset: any DatasetProviding) -> Artwork? {
        let candidates = dataset.pricedArtworks.isEmpty ? dataset.pool.artworks : dataset.pricedArtworks
        guard !candidates.isEmpty else { return nil }
        var rng = SplitMix64(seed: fnv1a64("artprice|potd|\(day.isoString)"))
        return candidates[rng.nextInt(candidates.count)]
    }

    /// A representative work for a mode tile's painting detail (deterministic per mode).
    static func tileArtwork(for mode: GameMode, dataset: any DatasetProviding) -> Artwork? {
        let candidates = dataset.pricedArtworks.isEmpty ? dataset.pool.artworks : dataset.pricedArtworks
        guard !candidates.isEmpty else { return nil }
        var rng = SplitMix64(seed: fnv1a64("artprice|tile|\(mode.rawValue)"))
        return candidates[rng.nextInt(candidates.count)]
    }

    /// "Day N" of the daily challenge (1 on launch day; never below 1).
    static func dailyNumber(on day: DayKey) -> Int {
        max(1, day.dayNumber - launchDay.dayNumber + 1)
    }

    /// Whether today's daily challenge can be generated from this dataset.
    static func dailyIsBuildable(on day: DayKey, dataset: any DatasetProviding) -> Bool {
        (try? DailyService.challenge(for: day, dataset: dataset)) != nil
    }

    /// "MONDAY 12 OCTOBER" source text (rendered in small caps); local Gregorian calendar.
    static func dateLine(_ day: DayKey, locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)
        guard let date = calendar.date(from: components) else { return day.isoString }
        var style = Date.FormatStyle(date: .complete, time: .omitted, locale: locale, calendar: calendar)
        style = style.weekday(.wide).day().month(.wide)
        return date.formatted(style)
    }
}
