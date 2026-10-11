@testable import ArtDesign
import CoreGraphics
import Testing

@Suite("Round 3: slider geometry, layout tokens, share marks")
struct Round3Tests {
    @Test func sliderGeometryStaysInsideInsets() {
        let g = LogSliderGeometry(bounds: 200...700, width: 300)
        #expect(g.x(for: 200) == LogSliderGeometry.inset)
        #expect(g.x(for: 700) == 300 - LogSliderGeometry.inset)
        for p in 200...700 {
            let x = g.x(for: p)
            #expect(x >= LogSliderGeometry.inset && x <= 300 - LogSliderGeometry.inset)
            #expect(abs(g.position(atX: x) - Double(p)) < 1e-9)
        }
    }

    @Test func layoutTokens() {
        #expect(Tokens.Layout.artworkHeightFraction >= 0.55 && Tokens.Layout.artworkHeightFraction <= 0.62)
        #expect(Tokens.Layout.winnerLift == 1.02)
        #expect(Tokens.Layout.disabledTileOpacity == 0.6)
        #expect(Tokens.Layout.pricierFrameFraction == 0.42)
    }

    @Test func shareMarksArePublicAndDistinct() {
        let marks: [ShareMark] = [.hit, .close, .miss]
        #expect(Set(marks.map(\.symbol)).count == 3)
        #expect(marks.map(\.label) == ["hit", "close", "miss"])
    }
}
