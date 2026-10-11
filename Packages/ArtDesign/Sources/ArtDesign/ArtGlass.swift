import SwiftUI

// The single entry point for translucent chrome. Rules (AGENTS.md rule 4, plan Part D1):
// glass only on static floating controls (close button, bottom action bar, score capsule);
// never over artwork, on moving cards, or inside share cards.

extension View {
    /// Liquid Glass on iOS 26+, `.ultraThinMaterial` + 0.5pt hairline on iOS 18–25, and a solid
    /// `bg.elevated` fill + hairline when Reduce Transparency is on.
    ///
    /// - Parameters:
    ///   - shape: The glass shape (e.g. `Capsule()`, `Circle()`, `RoundedRectangle(cornerRadius:style:)`).
    ///   - interactive: Glass reacts to touch (iOS 26+). Use for tappable controls.
    ///   - tint: Optional tint (e.g. `Tokens.Color.accentGilt` for the primary action only).
    public func artGlass<S: Shape>(_ shape: S, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(ArtGlassModifier(shape: shape, interactive: interactive, tint: tint))
    }

    /// `artGlass` in a capsule (score capsule, action bars).
    public func artGlass(interactive: Bool = false, tint: Color? = nil) -> some View {
        artGlass(Capsule(), interactive: interactive, tint: tint)
    }
}

/// Implementation of `artGlass(_:interactive:tint:)`.
struct ArtGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let tint: Color?
    @Environment(\.artReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            solid(content)
        } else {
            glass(content)
        }
    }

    private func solid(_ content: Content) -> some View {
        content
            .background(tint ?? Tokens.Color.bgElevated, in: shape)
            .overlay(shape.stroke(Tokens.Color.lineHairline, lineWidth: Tokens.Size.hairline))
    }

    @ViewBuilder
    private func glass(_ content: Content) -> some View {
        // iOS is the target. The macOS 26 branch only exists so the same API calls type-check
        // with the Command Line Tools on the build Mac (no iOS SDK there).
        #if os(iOS) || os(macOS)
        if #available(iOS 26, macOS 26, *) {
            content.glassEffect(glassValue, in: shape)
        } else {
            material(content)
        }
        #else
        material(content)
        #endif
    }

    @available(iOS 26, macOS 26, *)
    private var glassValue: Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint) }
        if interactive { g = g.interactive() }
        return g
    }

    private func material(_ content: Content) -> some View {
        content
            .background {
                if let tint {
                    shape.fill(tint)
                } else {
                    shape.fill(.ultraThinMaterial)
                }
            }
            .overlay(shape.stroke(Tokens.Color.lineHairline, lineWidth: Tokens.Size.hairline))
    }
}

// MARK: - Buttons

/// Button treatments. `.prominent` is the one primary CTA per screen (gilt); `.secondary` is chrome.
public enum ArtButtonStyle: Sendable {
    /// iOS 26+: `.glassProminent` tinted gilt. iOS 18–25 and Reduce Transparency: `.borderedProminent` gilt.
    case prominent
    /// iOS 26+: `.glass`. iOS 18–25: material + hairline. Reduce Transparency: solid `bg.elevated`.
    /// For floating chrome only (e.g. a summary's "Home"), never for answers.
    case secondary
    /// Answer options (pick the price, category chips): solid `bg.surface`, hairline, 56pt minimum,
    /// full width, no glass and no shadow, on every OS version. Pair with `.revealOption(…)`.
    case option
}

extension View {
    /// Applies an `ArtButtonStyle` with token radius (14pt), minimum 56pt height and the glass split.
    public func artButtonStyle(_ style: ArtButtonStyle) -> some View {
        modifier(ArtButtonStyleModifier(style: style))
    }
}

/// Implementation of `artButtonStyle(_:)`.
struct ArtButtonStyleModifier: ViewModifier {
    let style: ArtButtonStyle
    @Environment(\.artReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        styled(content)
            .buttonBorderShape(.roundedRectangle(radius: Tokens.Radius.control))
            .controlSize(.large)
            .font(ArtFont.label)
    }

    @ViewBuilder
    private func styled(_ content: Content) -> some View {
        switch style {
        case .prominent:
            prominent(content)
        case .option:
            content.buttonStyle(ArtOptionButtonStyle())
        case .secondary:
            if reduceTransparency {
                content.buttonStyle(ArtSolidButtonStyle())
            } else {
                secondaryGlass(content)
            }
        }
    }

    @ViewBuilder
    private func prominent(_ content: Content) -> some View {
        #if os(iOS) || os(macOS)
        if #available(iOS 26, macOS 26, *), !reduceTransparency {
            content.buttonStyle(.glassProminent).tint(Tokens.Color.accentGilt)
                .foregroundStyle(Tokens.Color.textOnGilt)
        } else {
            content.buttonStyle(.borderedProminent).tint(Tokens.Color.accentGilt)
                .foregroundStyle(Tokens.Color.textOnGilt)
        }
        #else
        content.buttonStyle(.borderedProminent).tint(Tokens.Color.accentGilt)
        #endif
    }

    @ViewBuilder
    private func secondaryGlass(_ content: Content) -> some View {
        #if os(iOS) || os(macOS)
        if #available(iOS 26, macOS 26, *) {
            content.buttonStyle(.glass).foregroundStyle(Tokens.Color.textPrimary)
        } else {
            content.buttonStyle(ArtMaterialButtonStyle())
        }
        #else
        content.buttonStyle(ArtMaterialButtonStyle())
        #endif
    }
}

/// iOS 18–25 secondary button: material + hairline, 56pt minimum height.
struct ArtMaterialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Tokens.Color.textPrimary)
            .padding(.horizontal, Tokens.Space.l)
            .frame(minHeight: Tokens.Size.answerButton)
            .artGlass(RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous))
    }
}

/// Reduce Transparency secondary button: solid `bg.elevated` + hairline.
struct ArtSolidButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous)
        configuration.label
            .foregroundStyle(Tokens.Color.textPrimary)
            .padding(.horizontal, Tokens.Space.l)
            .frame(minHeight: Tokens.Size.answerButton)
            .background(Tokens.Color.bgElevated, in: shape)
            .overlay(shape.stroke(Tokens.Color.lineHairline, lineWidth: Tokens.Size.hairline))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(shape)
    }
}

/// Reveal state of an answer option (`artButtonStyle(.option)`), shared by Pick and Category.
nonisolated public enum ArtOptionState: Sendable, Equatable {
    /// Before the reveal: solid surface + hairline.
    case normal
    /// The right answer after the reveal: filled `feedback.hit`, text `text.onHit`.
    case correct
    /// Not the answer after the reveal: dimmed to `motion.reveal.dimOpacity` (35%).
    case incorrect
}

extension EnvironmentValues {
    /// Reveal state applied by `ArtOptionButtonStyle`. Set it with `.artOptionState(_:)`.
    public var artOptionState: ArtOptionState {
        get { self[ArtOptionStateKey.self] }
        set { self[ArtOptionStateKey.self] = newValue }
    }
}

private struct ArtOptionStateKey: EnvironmentKey {
    static let defaultValue: ArtOptionState = .normal
}

extension View {
    /// Sets the reveal state of `artButtonStyle(.option)` buttons in this subtree. The state changes
    /// animate with the reveal settle spring (crossfade under Reduce Motion). Pair the visual state
    /// with an icon + word (never colour alone); for the player's own wrong pick, add the gilt outline
    /// from `revealOption(isChosen:phase:)` instead of using `.incorrect`'s dimming alone.
    public func artOptionState(_ state: ArtOptionState) -> some View {
        environment(\.artOptionState, state)
            .artAnimation(Tokens.Motion.Spring.settle, value: state)
    }
}

/// Answer option: solid surface + hairline, 56pt minimum, full width, label leading.
/// `.correct` fills with `feedback.hit`; `.incorrect` dims to 35%.
struct ArtOptionButtonStyle: ButtonStyle {
    @Environment(\.artOptionState) private var state

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous)
        configuration.label
            .foregroundStyle(state == .correct ? Tokens.Color.textOnHit : Tokens.Color.textPrimary)
            .padding(.horizontal, Tokens.Space.l)
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.answerButton, alignment: .leading)
            .background(fill(pressed: configuration.isPressed), in: shape)
            .overlay(shape.strokeBorder(state == .correct ? Color.clear : Tokens.Color.lineHairline,
                                        lineWidth: Tokens.Size.hairline))
            .opacity(state == .incorrect ? Tokens.Motion.Reveal.dimOpacity : 1)
            .contentShape(shape)
    }

    private func fill(pressed: Bool) -> Color {
        switch state {
        case .correct: Tokens.Color.feedbackHit
        case .incorrect, .normal: pressed ? Tokens.Color.bgElevated : Tokens.Color.bgSurface
        }
    }
}
