@testable import ArtDesign
import CoreGraphics
import Testing

@Suite("Round 4: tokens, option states, bracket labels")
struct Round4Tests {
    @Test func requestedTokens() {
        #expect(Tokens.Layout.onboardingEraFraction == 0.3)
        #expect(Tokens.Layout.onboardingTileFraction == 0.18)
        #expect(Tokens.Layout.tileDetailAspect == 1.6)
        #expect(Tokens.Layout.clueZoom == 1.6)
        #expect(Tokens.Motion.Duration.step == 0.35)
        #expect(Tokens.Motion.Reveal.teachAt == 0.35)
        #expect(Tokens.Layout.bracketLabelMaxRows == 2)
    }

    // Brackets centred at 150 on a 300pt track: 10× widest, 2× narrowest; labels 24pt wide.
    func items(scale: CGFloat) -> [BracketLabelLayout.Item] {
        [(0, 100.0), (1, 70.0), (2, 30.0)].map { id, reach in
            BracketLabelLayout.Item(id: id, left: 150 - reach * scale, right: 150 + reach * scale, labelWidth: 24)
        }
    }

    func overlaps(_ placements: [BracketLabelLayout.Placement]) -> Bool {
        for a in placements {
            for b in placements where a.id < b.id && a.row == b.row {
                if a.minX < b.minX + 24 + Tokens.Space.xs && b.minX < a.minX + 24 + Tokens.Space.xs { return true }
            }
        }
        return false
    }

    @Test func wideBracketsShareOneRow() {
        let p = BracketLabelLayout.place(items(scale: 1), trackWidth: 300)
        #expect(p.count == 3)
        #expect(p.allSatisfy { $0.row == 0 })
        #expect(!overlaps(p))
    }

    @Test(arguments: [0.5, 0.3, 0.15, 0.05, 0.0])
    func narrowBracketsNeverOverlap(scale: Double) {
        let p = BracketLabelLayout.place(items(scale: CGFloat(scale)), trackWidth: 300)
        #expect(!overlaps(p))
        #expect(p.contains { $0.id == 0 })                 // widest label always shown
        #expect(p.allSatisfy { $0.row < Int(Tokens.Layout.bracketLabelMaxRows) })
        #expect(p.allSatisfy { $0.minX >= 0 && $0.minX + 24 <= 300 })
    }

    @Test func collapsesToSingleLabelWhenOneRow() {
        let p = BracketLabelLayout.place(items(scale: 0), trackWidth: 300, maxRows: 1)
        #expect(p.map(\.id) == [0])
    }

    @Test func labelsClampInsideTrack() {
        let edge = [BracketLabelLayout.Item(id: 0, left: 280, right: 340, labelWidth: 24)]
        #expect(BracketLabelLayout.place(edge, trackWidth: 300).first?.minX == 276)
    }

    @MainActor @Test func optionStateDefault() {
        #expect(EnvironmentValuesProbe.defaultOptionState == .normal)
    }
}

import SwiftUI
@MainActor enum EnvironmentValuesProbe {
    static var defaultOptionState: ArtOptionState { EnvironmentValues().artOptionState }
}
