import SwiftUI

/// Named animations built from motion tokens. "Slow in, decisive settle, like a gavel."
nonisolated public enum ArtMotion {
    /// General reveal spring (response 0.45, damping 0.82).
    public static var reveal: Animation { Tokens.Motion.Spring.settle }
    /// The settle beat of the hammer reveal (scale 1.04 → 1.0).
    public static var settle: Animation { Tokens.Motion.Spring.settle }
    /// A swipe card returning to centre (0.35 / 0.70).
    public static var snapBack: Animation { Tokens.Motion.Spring.snapBack }
    /// Higher-or-lower chaining (0.40 / 0.85).
    public static var chain: Animation { Tokens.Motion.Spring.chain }
    /// Entrance ease-out at the reveal duration (450ms).
    public static var entrance: Animation { Tokens.Motion.Easing.entrance(duration: Tokens.Motion.Duration.reveal) }
    /// Fast state change (150ms).
    public static var fast: Animation { Tokens.Motion.Easing.standard(duration: Tokens.Motion.Duration.fast) }
    /// Reduce Motion crossfade (200ms ease-in-out).
    public static var crossfade: Animation { .easeInOut(duration: Tokens.Motion.Reduced.crossfade) }

    /// `animation`, or the crossfade when Reduce Motion is on.
    public static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? crossfade : animation
    }
}

/// `withAnimation` that substitutes the Reduce Motion crossfade.
@discardableResult
public func withArtAnimation<Result>(_ animation: Animation, reduceMotion: Bool,
                                     _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(ArtMotion.resolved(animation, reduceMotion: reduceMotion), body)
}

/// Reads Reduce Motion and swaps any movement for a 200ms crossfade.
///
/// Apply to a view whose appearance depends on `value`: with Reduce Motion off it animates with
/// `animation`; with it on, geometry effects (offset/scale/rotation) are dropped by the caller via
/// `reduceMotion` and only opacity animates.
public struct ReduceMotionAware<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    @Environment(\.artReduceMotion) private var reduceMotion

    /// Creates the modifier.
    public init(animation: Animation, value: V) {
        self.animation = animation
        self.value = value
    }

    public func body(content: Content) -> some View {
        content.animation(ArtMotion.resolved(animation, reduceMotion: reduceMotion), value: value)
    }
}

extension View {
    /// Animates changes of `value` with `animation`, or a crossfade under Reduce Motion.
    public func artAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(ReduceMotionAware(animation: animation, value: value))
    }

    /// Uses `transition`, or `.opacity` under Reduce Motion.
    public func artTransition(_ transition: AnyTransition) -> some View {
        modifier(ArtTransitionModifier(transition: transition))
    }
}

/// Implementation of `artTransition(_:)`.
struct ArtTransitionModifier: ViewModifier {
    let transition: AnyTransition
    @Environment(\.artReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? .opacity : transition)
    }
}
