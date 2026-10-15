import Foundation
import Observation
import SwiftUI

// The shared "hammer reveal" choreography (plan Part C3), reused by every mode:
//
//   t=0        lock       input locks; haptic select.commit
//   0–150ms    dim        unchosen options fade to 35%; chosen outlined gilt
//   150–600ms  roll       price counter rolls from guess (or "$—") to true value on a log path
//   600ms      settle     spring 1.04 → 1.0; haptic result.hit / result.miss
//   650–900ms  provenance provenance line fades in, rising 6pt
//   900ms      next       Next button appears
//
// Reduce Motion: everything resolves in one 200ms crossfade (no roll, no scale, no rise).

/// Phases of the hammer reveal, in order.
nonisolated public enum RevealPhase: Int, Comparable, CaseIterable, Sendable {
    case idle, lock, dim, roll, settle, provenance, next

    public static func < (lhs: RevealPhase, rhs: RevealPhase) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// One scheduled step of the reveal timeline.
nonisolated public struct RevealStep: Sendable, Equatable {
    /// Phase entered at `at`.
    public let phase: RevealPhase
    /// Seconds from input lock.
    public let at: Double
}

/// The reveal timeline from motion tokens (pure; unit-tested).
nonisolated public enum RevealTimeline {
    /// Steps for the full choreography, or the Reduce Motion crossfade.
    public static func steps(reduceMotion: Bool) -> [RevealStep] {
        typealias R = Tokens.Motion.Reveal
        if reduceMotion {
            return [
                RevealStep(phase: .lock, at: 0),
                RevealStep(phase: .provenance, at: 0),
                RevealStep(phase: .next, at: Tokens.Motion.Reduced.crossfade),
            ]
        }
        return [
            RevealStep(phase: .lock, at: 0),
            RevealStep(phase: .dim, at: R.dimStart),
            RevealStep(phase: .roll, at: R.rollStart),
            RevealStep(phase: .settle, at: R.settleAt),
            RevealStep(phase: .provenance, at: R.provenanceStart),
            RevealStep(phase: .next, at: R.nextAt),
        ]
    }

    /// Animation used when entering `phase`.
    public static func animation(entering phase: RevealPhase, reduceMotion: Bool) -> Animation? {
        typealias R = Tokens.Motion.Reveal
        if reduceMotion { return ArtMotion.crossfade }
        switch phase {
        case .idle, .lock: return nil
        case .dim: return Tokens.Motion.Easing.standard(duration: R.dimEnd - R.dimStart)
        case .roll: return Tokens.Motion.Easing.roll(duration: R.rollEnd - R.rollStart)
        case .settle: return Tokens.Motion.Spring.settle
        case .provenance: return Tokens.Motion.Easing.entrance(duration: R.provenanceEnd - R.provenanceStart)
        case .next: return Tokens.Motion.Easing.entrance(duration: Tokens.Motion.Duration.base)
        }
    }
}

/// Runs the reveal timeline. Own one per round view (`@State private var reveal = HammerRevealDriver()`),
/// call `start(…)` when the player answers, and read `phase` in the view.
@Observable
public final class HammerRevealDriver {
    /// Current phase.
    public private(set) var phase: RevealPhase = .idle
    /// Whether the player's answer was correct / within tier (drives the settle haptic).
    public private(set) var isHit = false

    @ObservationIgnored private var task: Task<Void, Never>?

    /// Creates an idle driver.
    public init() {}

    /// Input is locked from `lock` until the next round.
    public var isLocked: Bool { phase >= .lock }

    /// Starts the timeline.
    /// - Parameters:
    ///   - isHit: Outcome, for the settle haptic and colouring.
    ///   - reduceMotion: Pass `@Environment(\.artReduceMotion)`.
    ///   - announcement: One VoiceOver sentence posted at settle (e.g. "Correct. Sold for about
    ///     82 million dollars in 1990.").
    public func start(isHit: Bool, reduceMotion: Bool, announcement: String? = nil) {
        guard phase == .idle else { return }
        self.isHit = isHit
        phase = .lock // synchronous: input is locked before the next touch can land
        let steps = RevealTimeline.steps(reduceMotion: reduceMotion).filter { $0.phase > .lock }
        task = Task { [weak self] in
            let clock = ContinuousClock()
            let start = clock.now
            for step in steps {
                try? await clock.sleep(until: start.advanced(by: .seconds(step.at)))
                guard let self, !Task.isCancelled else { return }
                withAnimation(RevealTimeline.animation(entering: step.phase, reduceMotion: reduceMotion)) {
                    self.phase = step.phase
                }
                if let announcement, step.phase == (reduceMotion ? .provenance : .settle) {
                    AccessibilityNotification.Announcement(announcement).post()
                }
            }
        }
    }

    /// Jumps to the end (e.g. the player taps the artwork to advance early).
    public func skipToEnd() {
        task?.cancel()
        phase = .next
    }

    /// Back to idle for the next round.
    public func reset() {
        task?.cancel()
        task = nil
        phase = .idle
        isHit = false
    }
}

// MARK: - Modifiers

extension View {
    /// Answer-option treatment: unchosen options dim to 35% from `dim`; the chosen one gets a gilt
    /// outline. Use on each option of pick-price, category and pricier modes.
    public func revealOption(isChosen: Bool, phase: RevealPhase,
                             shape: some InsettableShape = RoundedRectangle(cornerRadius: Tokens.Radius.control,
                                                                            style: .continuous)) -> some View {
        self
            .opacity(phase >= .dim && !isChosen ? Tokens.Motion.Reveal.dimOpacity : 1)
            .overlay {
                if isChosen && phase >= .dim {
                    shape.strokeBorder(Tokens.Color.accentGilt, lineWidth: Tokens.Space.xxs)
                }
            }
    }

    /// The settle beat: scale pulses to 1.04 and springs back when the phase reaches `settle`.
    /// No-op under Reduce Motion.
    public func revealSettle(phase: RevealPhase) -> some View {
        modifier(RevealSettleModifier(isSettled: phase >= .settle))
    }

    /// Provenance line: hidden until `provenance`, then fades in rising 6pt (fade only under Reduce Motion).
    public func revealProvenance(phase: RevealPhase) -> some View {
        modifier(RevealRiseModifier(isVisible: phase >= .provenance))
    }

    /// Next button: hidden (and not hit-testable) until `next`.
    public func revealNext(phase: RevealPhase) -> some View {
        self
            .opacity(phase >= .next ? 1 : 0)
            .allowsHitTesting(phase >= .next)
            .accessibilityHidden(phase < .next)
    }

    /// Plays select.commit at lock and result.hit / result.miss at settle (Reduce Motion skips straight
    /// past settle, so the result haptic fires with the crossfade).
    public func revealHaptics(_ driver: HammerRevealDriver) -> some View {
        self
            .artHaptic(.selectCommit, trigger: driver.phase >= .lock) { old, new in !old && new }
            .artHaptic(driver.isHit ? .resultHit : .resultMiss, trigger: driver.phase >= .settle) { old, new in
                !old && new
            }
    }
}

struct RevealSettleModifier: ViewModifier {
    let isSettled: Bool
    @Environment(\.artReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: CGFloat(1), trigger: isSettled) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    if isSettled {
                        CubicKeyframe(Tokens.Motion.Reveal.settleScale, duration: Tokens.Motion.Duration.instant)
                        SpringKeyframe(1, spring: Spring(response: Tokens.Motion.Spring.settleResponse,
                                                         dampingRatio: Tokens.Motion.Spring.settleDampingFraction))
                    } else {
                        LinearKeyframe(1, duration: 0)
                    }
                }
            }
        }
    }
}

struct RevealRiseModifier: ViewModifier {
    let isVisible: Bool
    @Environment(\.artReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : Tokens.Motion.Reveal.provenanceRise)
            .accessibilityHidden(!isVisible)
    }
}

// MARK: - Rolling price

/// The price counter. Shows the guess (or "$—") until `roll`, then rolls to `actual` along a log
/// path (the phase change carries the roll easing). Under Reduce Motion it crossfades instead.
/// Style it with `.artTextStyle(Tokens.Typography.priceHero)`.
public struct RevealPrice: View {
    private let guess: Double?
    private let actual: Double
    private let finalText: String?
    private let phase: RevealPhase
    @Environment(\.artReduceMotion) private var reduceMotion

    /// Creates the counter.
    /// - Parameters:
    ///   - guess: The player's guess in USD, or `nil` (shows "$—").
    ///   - actual: The true price in USD.
    ///   - finalText: Exact text to land on (e.g. "≈ $82.5M"); defaults to the 2-sf format.
    ///   - phase: The driver's phase.
    public init(guess: Double?, actual: Double, finalText: String? = nil, phase: RevealPhase) {
        self.guess = guess
        self.actual = actual
        self.finalText = finalText
        self.phase = phase
    }

    public var body: some View {
        Group {
            if reduceMotion {
                Text(phase >= .settle ? landed : start)
                    .contentTransition(.opacity)
            } else if phase >= .settle {
                Text(landed)
            } else if phase >= .roll || guess != nil {
                RollingPriceText(log: phase >= .roll ? log10(max(actual, 1)) : startLog)
            } else {
                Text(verbatim: "$—")
            }
        }
        .monospacedDigit()
        .accessibilityLabel(Text(SpokenPrice.text(phase >= .settle ? landed : start)))
    }

    private var landed: String { finalText ?? LogPriceScale.format(actual) }
    private var start: String { guess.map(LogPriceScale.format) ?? "$—" }
    /// Without a guess the roll starts one decade below the truth.
    private var startLog: Double { log10(max(guess ?? actual / 10, 1)) }
}

/// Text whose value interpolates in log10 space while animating.
struct RollingPriceText: View, Animatable {
    var log: Double

    nonisolated var animatableData: Double {
        get { log }
        set { log = newValue }
    }

    var body: some View {
        Text(LogPriceScale.format(pow(10, log)))
    }
}
