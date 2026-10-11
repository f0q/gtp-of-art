import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Full-screen questionnaire: progress dots, Skip top-right, one image step at a time with a
/// 350ms crossfade between steps.
struct OnboardingView: View {
    @Bindable var model: OnboardingModel
    @Environment(\.artReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.l) {
                    Text(model.title)
                        .artTextStyle(Tokens.Typography.displayL)
                        .foregroundStyle(Tokens.Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("onboarding.title")
                    if let subtitle = model.subtitle {
                        Text(subtitle)
                            .artTextStyle(Tokens.Typography.body)
                            .foregroundStyle(Tokens.Color.textSecondary)
                    }
                    stepContent
                }
                .padding(.horizontal, Tokens.Space.l)
                .padding(.vertical, Tokens.Space.m)
                .id(model.step)
                .transition(.opacity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            if model.step == 2 {
                SessionPrimaryButton(title: "Continue", identifier: "onboarding.continue") {
                    animate { model.continueFromDepartments() }
                }
                .disabled(!model.canContinue)
                .padding(.horizontal, Tokens.Space.l)
                .padding(.bottom, Tokens.Space.s)
            }
        }
        .background(Tokens.Color.bgCanvas.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: Tokens.Space.s) {
                ForEach(1...OnboardingModel.stepCount, id: \.self) { i in
                    Circle()
                        .fill(i <= model.step ? Tokens.Color.textPrimary : Tokens.Color.lineHairline)
                        .frame(width: Tokens.Space.s, height: Tokens.Space.s)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Question \(model.step) of \(OnboardingModel.stepCount)")
            Spacer()
            Button("Skip") { model.skip() }
                .artTextStyle(Tokens.Typography.label)
                .foregroundStyle(Tokens.Color.textPrimary)
                .padding(.horizontal, Tokens.Space.l)
                .frame(minHeight: Tokens.Size.minTarget)
                .artGlass(interactive: true)
                .accessibilityIdentifier("onboarding.skip")
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.top, Tokens.Space.s)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case 1:
            VStack(spacing: Tokens.Space.l) {
                ForEach(model.choices) { choice in tile(choice, heightFraction: Tokens.Layout.onboardingEraFraction) }
            }
        case 5:
            VStack(spacing: Tokens.Space.m) {
                ForEach(OnboardingModel.intents, id: \.intent) { item in
                    Button { model.choose(item.intent) } label: {
                        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                            Text(item.title).artTextStyle(Tokens.Typography.label)
                            Text(item.detail)
                                .artTextStyle(Tokens.Typography.provenance)
                                .foregroundStyle(Tokens.Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: Tokens.Size.answerButton, alignment: .leading)
                    }
                    .artButtonStyle(.secondary)
                    .accessibilityIdentifier("onboarding.intent.\(item.intent.rawValue)")
                }
            }
        default:
            let columns = typeSize.isAccessibilitySize ? 1 : 2
            let rows = stride(from: 0, to: model.choices.count, by: columns).map {
                Array(model.choices[$0..<min($0 + columns, model.choices.count)])
            }
            VStack(spacing: Tokens.Space.m) {
                ForEach(rows, id: \.first?.id) { row in
                    HStack(alignment: .top, spacing: Tokens.Space.m) {
                        ForEach(row) { tile($0, heightFraction: Tokens.Layout.onboardingTileFraction) }
                        if row.count < columns { Color.clear.frame(maxWidth: .infinity) }
                    }
                }
            }
        }
    }

    private func tile(_ choice: OnboardingChoice, heightFraction: CGFloat) -> some View {
        OnboardingTile(
            choice: choice, exemplar: model.exemplar(for: choice), isSelected: model.isSelected(choice),
            heightFraction: heightFraction
        ) {
            animate { model.choose(choice) }
        }
    }

    private func animate(_ change: () -> Void) {
        withAnimation(reduceMotion ? ArtMotion.crossfade : .easeInOut(duration: Tokens.Motion.Duration.step), change)
    }
}

/// An image choice: exemplar artwork, label and caption; gilt outline when selected (step 2).
struct OnboardingTile: View {
    let choice: OnboardingChoice
    let exemplar: (artwork: Artwork, caption: String)?
    let isSelected: Bool
    let heightFraction: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Tokens.Space.s) {
                if let exemplar {
                    ArtworkImage(artwork: exemplar.artwork, rendition: .small, decorative: true)
                        .containerRelativeFrame(.vertical) { length, _ in length * heightFraction }
                }
                HStack(spacing: Tokens.Space.xs) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.Color.accentGilt)
                    }
                    Text(choice.label)
                        .artTextStyle(Tokens.Typography.titleArt)
                        .foregroundStyle(Tokens.Color.textPrimary)
                }
                if let exemplar {
                    Text(exemplar.caption)
                        .artTextStyle(Tokens.Typography.provenance)
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Tokens.Space.m)
            .frame(maxWidth: .infinity)
            .background(Tokens.Color.bgSurface, in: RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? Tokens.Color.accentGilt : Tokens.Color.lineHairline,
                                  lineWidth: isSelected ? Tokens.Space.xxs : Tokens.Size.hairline))
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(choice.label). \(exemplar?.caption ?? "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("onboarding.choice.\(choice.id)")
    }
}

/// Presents onboarding while the profile says the questionnaire has not been done; completing (or
/// skipping) sets `hasOnboarded`, which dismisses it. "Redo questionnaire" clears the flag again.
struct OnboardingGate: ViewModifier {
    @Environment(\.app) private var app
    @Environment(ProfileModel.self) private var profile
    @State private var model: OnboardingModel?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $model) { OnboardingView(model: $0) }
            .onChange(of: needsOnboarding, initial: true) { _, needed in
                model = needed ? OnboardingModel(dataset: app.dataset, profile: profile) : nil
            }
    }

    private var needsOnboarding: Bool { profile.isLoaded && !profile.profile.hasOnboarded }
}

extension View {
    /// Shows the questionnaire full-screen until the player has onboarded.
    func onboardingGate() -> some View { modifier(OnboardingGate()) }
}
