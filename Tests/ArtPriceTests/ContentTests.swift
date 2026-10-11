import ArtDesign
import ArtCore
import ArtData
import Foundation
import Testing
@testable import ArtPrice

@Suite("Hub and price copy")
struct ContentTests {
    @Test("Painting of the Day is deterministic per day and priced")
    func paintingOfTheDay() throws {
        let day = DayKey(year: 2026, month: 10, day: 12)
        let a = HomeContent.paintingOfTheDay(on: day, dataset: TestSupport.dataset)
        let b = HomeContent.paintingOfTheDay(on: day, dataset: TestSupport.dataset)
        #expect(a != nil && a?.id == b?.id)
        #expect(a?.gamePrice != nil)
        let week = (0..<7).compactMap { HomeContent.paintingOfTheDay(on: day.adding(days: $0), dataset: TestSupport.dataset)?.id }
        #expect(Set(week).count > 1)
    }

    @Test("Daily numbering starts at 1")
    func dailyNumber() {
        #expect(HomeContent.dailyNumber(on: DayKey(year: 2026, month: 10, day: 12)) == 1)
        #expect(HomeContent.dailyNumber(on: DayKey(year: 2026, month: 10, day: 20)) == 9)
        #expect(HomeContent.dailyNumber(on: DayKey(year: 2026, month: 1, day: 1)) == 1)
    }

    @Test("Tiles: every mode playable")
    func tiles() {
        #expect(HomeContent.tiles.filter(\.isAvailable).map(\.mode) == [.pickPrice, .higherLower, .bid, .category, .swipe])
        #expect(HomeContent.tiles.count == 5)
    }

    @Test("Provenance line is approximate, dated and sourced")
    func provenance() throws {
        let artwork = try #require(TestSupport.dataset.pricedArtworks.first { $0.gamePrice?.type == .auctionPremium })
        let record = try #require(artwork.gamePrice)
        let line = PriceCopy.provenance(record, showVenue: true)
        #expect(line.hasPrefix("Sold \(record.saleYear ?? 0)"))
        #expect(line.contains("approx. $"))
        #expect(line.contains("incl. fees"))
        if let venue = record.venue { #expect(line.contains(venue)) }
        let hidden = PriceCopy.provenance(record, showVenue: false)
        if let venue = record.venue { #expect(!hidden.contains(venue)) }
    }

    @Test("Bid ratio copy")
    func ratio() {
        let posix = Locale(identifier: "en_US_POSIX")
        let under = BidScorer.score(position: 300, actualMilli: 5_490)
        #expect(PriceCopy.bidRatio(under, locale: posix) == "You were 3.1× under.")
        // The default follows PriceFormatter's convention ("." decimal) whatever the device locale.
        #expect(PriceCopy.bidRatio(under) == PriceCopy.bidRatio(under, locale: posix))
        #expect(PriceCopy.multiplier(12.4, locale: posix) == "12")
        let exact = BidScorer.score(position: 300, actualMilli: 5_000)
        #expect(PriceCopy.bidRatio(exact) == "You were spot on.")
    }

    @Test("Credits and disclaimer load from the bundle")
    func credits() throws {
        let credits = try #require(CreditsDocument.load())
        #expect(!credits.images.isEmpty)
        #expect(!credits.dataSources.isEmpty)
        #expect(TestSupport.dataset.disclaimer.contains("approximate"))
    }

    @Test("Fixed seeds are stable per mode and attempt")
    func seeds() {
        #expect(SeedPolicy.fixed.seed(for: .bid, attempt: 0) == SeedPolicy.fixed.seed(for: .bid, attempt: 0))
        #expect(SeedPolicy.fixed.seed(for: .bid, attempt: 0) != SeedPolicy.fixed.seed(for: .bid, attempt: 1))
    }
}
