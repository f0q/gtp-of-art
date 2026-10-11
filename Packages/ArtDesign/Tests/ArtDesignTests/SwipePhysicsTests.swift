import ArtDesign
import CoreGraphics
import Testing

@Suite("CardStack commit decision")
struct SwipePhysicsTests {
    let physics = SwipePhysics.standard
    let card = CGSize(width: 300, height: 450)

    func decide(x: CGFloat, y: CGFloat = 0, predictedX: CGFloat? = nil, vx: CGFloat = 0, vy: CGFloat = 0) -> SwipeOutcome {
        physics.decide(translation: CGSize(width: x, height: y),
                       predictedEndTranslation: CGSize(width: predictedX ?? x, height: y),
                       velocity: CGSize(width: vx, height: vy), cardSize: card)
    }

    @Test func tokensDriveThresholds() {
        #expect(physics.commitRatio == 0.35)
        #expect(physics.commitVelocity == 800)
        #expect(physics.predictedEndRatio == 0.8)
        #expect(physics.maxRotationDegrees == 12)
        #expect(physics.rotationDivisor == 20)
    }

    @Test func translationThreshold() {
        #expect(decide(x: 105) == .cancel)            // exactly 35% is not past it
        #expect(decide(x: 106) == .commit(.like))
        #expect(decide(x: -106) == .commit(.pass))
        #expect(decide(x: 50) == .cancel)
    }

    @Test func velocityThreshold() {
        #expect(decide(x: 20, vx: 800) == .commit(.like))
        #expect(decide(x: 20, vx: 799) == .cancel)
        #expect(decide(x: -10, vx: -1200) == .commit(.pass))
        // A fling reverses an over-threshold drag.
        #expect(decide(x: 150, vx: -900) == .commit(.pass))
        // Mostly vertical velocity is not a horizontal fling.
        #expect(decide(x: 20, vx: 850, vy: 2000) == .cancel)
    }

    @Test func predictedEnd() {
        #expect(decide(x: 60, predictedX: 241) == .commit(.like))
        #expect(decide(x: 60, predictedX: 240) == .cancel)
        #expect(decide(x: -60, predictedX: -300) == .commit(.pass))
    }

    @Test func swipeUpOpensDetails() {
        #expect(decide(x: 10, y: -120) == .details)     // > 25% of 450
        #expect(decide(x: 10, y: -100) == .cancel)
        #expect(decide(x: 200, y: -150) == .commit(.like)) // horizontal-dominant wins
    }

    @Test func rotationAndStamps() {
        #expect(physics.rotationDegrees(translationX: 100) == 5)
        #expect(physics.rotationDegrees(translationX: 1000) == 12)
        #expect(physics.rotationDegrees(translationX: -1000) == -12)
        #expect(physics.stampOpacity(translationX: 0, width: 300) == 0)
        #expect(abs(physics.stampOpacity(translationX: 52.5, width: 300) - 0.5) < 1e-9)
        #expect(physics.stampOpacity(translationX: -500, width: 300) == 1)
        #expect(physics.isPastThreshold(translationX: 106, width: 300))
        #expect(!physics.isPastThreshold(translationX: 104, width: 300))
    }
}
