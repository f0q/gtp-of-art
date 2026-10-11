import ArtDesign
import Foundation
import Testing

@Suite("LogPriceScale")
struct LogScaleTests {
    @Test func endpointsAndMilli() {
        #expect(LogPriceScale.milli(forPosition: 0) == 2000)
        #expect(LogPriceScale.milli(forPosition: 700) == 9000)
        #expect(abs(LogPriceScale.price(forPosition: 0) - 100) < 1e-9)
        #expect(abs(LogPriceScale.price(forPosition: 700) / 1e9 - 1) < 1e-12)
        #expect(LogPriceScale.milli(forPosition: -5) == 2000)
        #expect(LogPriceScale.milli(forPosition: 9999) == 9000)
    }

    @Test(arguments: Array(0...700))
    func positionPriceRoundTrip(position: Int) {
        #expect(LogPriceScale.position(forPrice: LogPriceScale.price(forPosition: position)) == position)
    }

    @Test func priceToPositionRounding() {
        #expect(LogPriceScale.position(forPrice: 82_500_000) == 592) // log10 = 7.9165
        #expect(LogPriceScale.position(forPrice: 1) == 0)
        #expect(LogPriceScale.position(forPrice: 5e12) == 700)
        #expect(LogPriceScale.position(forPrice: 0) == 0)
    }

    @Test func formattingTwoSignificantFigures() {
        #expect(LogPriceScale.format(850) == "$850")
        #expect(LogPriceScale.format(57_300) == "$57K")
        #expect(LogPriceScale.format(2_840_000) == "$2.8M")
        #expect(LogPriceScale.format(450_300_000) == "$450M")
        #expect(LogPriceScale.format(1_000_000_000) == "$1B")
        #expect(LogPriceScale.label(forPosition: 0) == "$100")
        #expect(LogPriceScale.label(forPosition: 300) == "$100K")
    }

    @Test func decadeLabels() {
        #expect(LogPriceScale.decadePositions.map(LogPriceScale.label(forPosition:))
                == ["$100", "$1K", "$10K", "$100K", "$1M", "$10M", "$100M", "$1B"])
    }

    @Test func minorTicksAtTwoAndFive() {
        #expect(LogPriceScale.minorPositions.count == 14)
        #expect(LogPriceScale.minorPositions.prefix(2) == [30, 70])
        #expect(LogPriceScale.label(forPosition: 130) == "$2K")
        #expect(LogPriceScale.label(forPosition: 170) == "$5K")
    }

    @Test func crossingIndicesChangeOnlyAtTicks() {
        var decadeChanges: [Int] = []
        var minorChanges: [Int] = []
        for p in 1...700 {
            if LogPriceScale.decadeIndex(p) != LogPriceScale.decadeIndex(p - 1) { decadeChanges.append(p) }
            if LogPriceScale.minorIndex(p) != LogPriceScale.minorIndex(p - 1) { minorChanges.append(p) }
        }
        #expect(decadeChanges == Array(stride(from: 100, through: 700, by: 100)))
        #expect(minorChanges == LogPriceScale.minorPositions)
    }

    @Test func steppersAlwaysChangeDisplayedPrice() {
        for p in 0..<700 {
            let up = LogPriceScale.nextDistinctPosition(from: p, direction: 1)
            #expect(up > p)
            #expect(up == 700 || LogPriceScale.displayPrice(forPosition: up) != LogPriceScale.displayPrice(forPosition: p))
        }
        #expect(LogPriceScale.nextDistinctPosition(from: 0, direction: -1) == 0)
        #expect(LogPriceScale.nextDistinctPosition(from: 700, direction: 1) == 700)
    }
}
