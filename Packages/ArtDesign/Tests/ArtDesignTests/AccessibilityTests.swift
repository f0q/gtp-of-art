import ArtDesign
import Testing

@Suite("Accessibility wording")
struct AccessibilityTests {
    @Test(arguments: [
        ("$2.8M", "2.8 million dollars"),
        ("$2.0M", "2 million dollars"),
        ("$57K", "57 thousand dollars"),
        ("$850", "850 dollars"),
        ("$1", "1 dollar"),
        ("$1B", "1 billion dollars"),
        ("≈$5.5M", "about 5.5 million dollars"),
        ("≈ $82M", "about 82 million dollars"),
        ("~$250M+", "about 250 million dollars or more"),
        ("$—", "$—"),
        ("Sold 2019 · Christie's · approx. $2.0M incl. fees", "Sold 2019 · Christie's · approx. 2 million dollars incl. fees"),
        ("Your bid $450K against $1.2M.", "Your bid 450 thousand dollars against 1.2 million dollars."),
        ("£1,571,250", "£1,571,250"),
        ("$1,500 Monet", "1500 dollars Monet"),
    ])
    func spokenPrices(_ pair: (String, String)) {
        #expect(SpokenPrice.text(pair.0) == pair.1)
    }

    @Test func sliderValueIsSpoken() {
        #expect(SpokenPrice.text(LogPriceScale.label(forPosition: 700)) == "1 billion dollars")
        #expect(SpokenPrice.text(LogPriceScale.label(forPosition: 0)) == "100 dollars")
    }

    @Test func thinnedDecadesKeepBothEnds() {
        #expect(LogPriceScale.thinnedDecades([0, 100, 200, 300, 400, 500, 600, 700]) == [0, 200, 400, 700])
        #expect(LogPriceScale.thinnedDecades([200, 300, 400, 500, 600]) == [200, 400, 600])
        #expect(LogPriceScale.thinnedDecades([200, 300, 400, 500]) == [200, 500])
        #expect(LogPriceScale.thinnedDecades([300, 400]) == [300, 400])
    }

    @Test func reduceMotionCrossfadeIsAtMost200ms() {
        let last = RevealTimeline.steps(reduceMotion: true).map(\.at).max() ?? 0
        #expect(last <= 0.2)
    }
}
