import ArtDesign
import ArtCore
import ArtData
import CoreGraphics
import Foundation
import Testing
@testable import ArtPrice

@Suite("Taste copy and reading")
struct TasteTests {
    @Test("The archetype table names all 16 ArtCore ids, uniquely")
    func archetypesCoverAllIDs() {
        #expect(Archetypes.allIDs.count == 16)
        #expect(Set(Archetypes.all.map(\.id)) == Set(Archetypes.allIDs))
        #expect(Set(Archetypes.all.map(\.name)).count == 16)
        for id in Archetypes.allIDs {
            let a = Archetypes.archetype(id)
            #expect(a.id == id)
            #expect(a.name.hasPrefix("The "))
            #expect(!a.line.isEmpty && a.line.count <= 80)
        }
        for id in TasteBaseline.sampleIDs(TestSupport.dataset.tasteBaseline) {
            #expect(Archetypes.allIDs.contains(id), "baseline id \(id) has a name")
        }
    }

    @Test("Edge copy below 3 and above 18 likes")
    func edges() {
        #expect(TasteEdge.of(likes: 2, swipes: 20) == .purist)
        #expect(TasteEdge.of(likes: 3, swipes: 20) == nil)
        #expect(TasteEdge.of(likes: 18, swipes: 20) == nil)
        #expect(TasteEdge.of(likes: 19, swipes: 20) == .omnivore)
        #expect(TasteEdge.purist.title == "The Purist")
        #expect(TasteEdge.omnivore.title == "The Omnivore")
    }

    @Test("Rarity copy follows visibility and always says estimated")
    func rarityCopy() {
        let template = RarityCalculator.rarity(
            dst: 0.1, swipeCount: 20, archetypeID: "OFES", baseline: TestSupport.dataset.tasteBaseline)
        func rarity(_ v: RarityVisibility, _ lo: Int, _ hi: Int, pct: Double) -> Rarity {
            var r = template
            r.visibility = v
            r.percentile = pct
            r.band = RarityBand(lower: lo, upper: hi)
            return r
        }
        #expect(TasteCopy.rarity(rarity(.hidden, 75, 90, pct: 80), swipeCount: 5)
            == "Swipe 7 more to see how rare your taste is (estimated).")
        #expect(TasteCopy.rarity(rarity(.band, 75, 90, pct: 80), swipeCount: 20)
            == "Rarer than ~75–90% of players (estimated).")
        #expect(TasteCopy.rarity(rarity(.band, 99, 100, pct: 99), swipeCount: 20)
            == "Rarer than ~99% of players (estimated).")
        #expect(TasteCopy.rarity(rarity(.exact, 90, 95, pct: 92.7), swipeCount: 45)
            == "Rarer than 92% of players (estimated).")
        #expect(TasteCopy.rarity(rarity(.band, 0, 50, pct: 30), swipeCount: 20).contains("estimated"))
        #expect(TasteCopy.share(7) == "About 7% of players share your archetype (estimated).")
        #expect(TasteCopy.edition(7) == "Edition 7 / 100")
    }

    @Test("Bucket explanations read as one phrase")
    func explanations() {
        let artwork = TestSupport.dataset.pool.artworks[0]
        let profile = TasteProfile().applying(TasteSwipe(artwork: artwork, liked: true))
        let template = TasteAnalyzer.analyze(profile, baseline: TestSupport.dataset.tasteBaseline).contributions[0]
        func c(_ bucket: String, _ value: Double) -> BucketContribution {
            var x = template
            x.bucket = bucket
            x.contribution = value
            return x
        }
        let label: (CategoryID) -> String? = { $0 == "baroque" ? "Baroque" : nil }
        #expect(TasteCopy.leaning([c("brightness:dark", 0.5), c("era:1600_1700", 0.4), c("mood:serene", -0.3)],
                                  categoryLabel: label) == "You lean toward dark, 17th-century pictures.")
        #expect(TasteCopy.leaning([c("subject:portrait", 0.5), c("mood:dramatic", 0.4)], categoryLabel: label)
            == "You lean toward dramatic portraits.")
        #expect(TasteCopy.leaning([c("category:baroque", 0.5), c("subject:landscape", 0.4)], categoryLabel: label)
            == "You lean toward Baroque works and landscapes.")
        #expect(TasteCopy.avoiding([c("brightness:dark", 0.5), c("subject:still_life", -0.2)], categoryLabel: label)
            == "You tend to pass on still lifes.")
        #expect(TasteCopy.leaning([c("mood:serene", -0.3)], categoryLabel: label) == nil)
    }

    @Test("Swipe progress copy")
    func progress() {
        #expect(TasteCopy.progress(card: 7, total: 20) == nil)
        #expect(TasteCopy.progress(card: 8, total: 20) == "12 more to reveal your taste")
        #expect(TasteCopy.progress(card: 20, total: 20) == "Last one, then your taste")
    }

    @Test("Pigment stops are deterministic, thinned and ordered")
    func pigmentStops() {
        let swatches = (0..<12).map { Swatch(red: $0 * 20, green: 100, blue: 255 - $0 * 20) }
        for axis in TasteAxis.allCases {
            let stops = axis.stops(from: swatches)
            #expect(stops.count == 5)
            #expect(stops == axis.stops(from: swatches.reversed()))
        }
        #expect(TasteAxis.era.stops(from: []).isEmpty)
        #expect(TasteAxis.position(-1) == 0 && TasteAxis.position(1) == 1 && TasteAxis.position(0) == 0.5)
        #expect(Swatch(hex: "#0A0B0C")?.hex == "#0A0B0C")
    }

    @Test("Bundled palettes decode for every work")
    func palettes() {
        let index = PaletteIndex.bundled
        for artwork in TestSupport.dataset.pool.artworks {
            #expect(!index.palette(for: artwork).isEmpty)
        }
    }

    @Test("Salon templates: one slot per work, inside the wall, non-overlapping", arguments: 1...7)
    func salonSlots(count: Int) {
        let slots = SalonLayout.slots(count: count)
        #expect(slots.count == count)
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        for (i, a) in slots.enumerated() {
            #expect(unit.contains(a))
            for b in slots[(i + 1)...] { #expect(!a.intersects(b)) }
        }
    }

    @Test("Collection counts unique playable works, latest swipe wins")
    func collection() throws {
        let dataset = TestSupport.dataset
        let ids = dataset.pool.artworks.prefix(3).map(\.id)
        func record(_ round: Round, _ answer: Answer, liked: Bool? = nil, index: Int) -> RoundRecord {
            RoundRecord(mode: .swipe, sessionSeed: 1, roundIndex: index, round: round, answer: answer,
                        outcome: RoundOutcome(isCorrect: nil, points: 0, liked: liked), day: nil, playedAt: 0)
        }
        let records = [
            record(.swipe(SwipeRound(artwork: ids[0])), .swipe(liked: true), liked: true, index: 0),
            record(.swipe(SwipeRound(artwork: ids[1])), .swipe(liked: false), liked: false, index: 1),
            record(.swipe(SwipeRound(artwork: ids[0])), .swipe(liked: false), liked: false, index: 2),
            record(.swipe(SwipeRound(artwork: "not-in-pool")), .swipe(liked: true), liked: true, index: 3),
            record(.bid(BidRound(artwork: ids[2], priceID: "x", actualMilli: 6000, actualUSD: 1_000_000)),
                   .bid(position: 1), index: 4),
        ]
        let content = CollectionContent(records: records, pool: dataset.pool)
        #expect(content.discovered == 3)
        #expect(content.total == dataset.pool.artworks.count)
        #expect(content.seen == [ids[2], ids[0], ids[1]])
        #expect(content.swipes[ids[0]] == false)
        #expect(content.swipes[ids[1]] == false)
        #expect(content.swipes[ids[2]] == nil)
        #expect(content.header == "3 / \(dataset.pool.artworks.count) discovered")
    }
}

extension TasteBaseline {
    fileprivate static func sampleIDs(_ baseline: TasteBaseline) -> [String] { baseline.archetypeShares.keys.sorted() }
}
