import ArtCore
import ArtDesign
import SwiftUI

/// Session layout: artwork zone on top, answer zone pinned to the thumb zone.
///
/// The artwork zone is offered an exact height for a given answer-zone height, so it never jumps
/// between question and reveal as long as the answer zone measures the same (overlay both phases in
/// a `ZStack`). It is offered at most `Tokens.Layout.artworkHeightFraction` of the space and at least
/// `Tokens.Size.artMinHeightRatio`; when the answers need more (large Dynamic Type) the stage scrolls.
/// The zone hugs its artwork and caption, and whatever height a landscape or square work leaves
/// over is split evenly above and below it, so artwork, caption and question read as one centred
/// column instead of leaving a void above the answers.
struct SessionStage<Art: View, Answers: View>: View {
    @ViewBuilder let art: Art
    @ViewBuilder let answers: Answers
    @State private var answersHeight: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let artMin = h * Tokens.Size.artMinHeightRatio
            let artMax = h * Tokens.Layout.artworkHeightFraction
            let available = h - answersHeight - Tokens.Space.l
            // At accessibility sizes the caption alone can outgrow the zone, so the stage always
            // scrolls there with the image pinned at `artMinHeightRatio` and the caption below it.
            if available >= artMin && !typeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    art.frame(maxHeight: min(artMax, available))
                        // Offered all of `available` (capped) before the spacers share the rest.
                        .layoutPriority(1)
                    Spacer(minLength: Tokens.Space.l)
                    measuredAnswers
                }
            } else {
                ScrollView {
                    VStack(spacing: Tokens.Space.l) {
                        art.environment(\.stageArtworkHeight, artMin)
                        measuredAnswers
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.top, Tokens.Space.m)
    }

    private var measuredAnswers: some View {
        answers
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { answersHeight = $0 }
    }
}

extension EnvironmentValues {
    /// Exact artwork image height inside a scrolling `SessionStage` (nil: fill the zone).
    @Entry var stageArtworkHeight: CGFloat? = nil
}

/// Artwork + caption within the zone it is given (the aspect-fit image shrinks first), hugging
/// the fitted image so the caption sits right under it. In a scrolling stage the image keeps
/// `stageArtworkHeight` and the caption grows below it.
struct ArtworkZone: View {
    let artwork: Artwork
    var onTap: (() -> Void)? = nil
    @Environment(\.stageArtworkHeight) private var fixedHeight

    var body: some View {
        VStack(spacing: Tokens.Space.s) {
            ArtworkImage(artwork: artwork)
                .frame(maxWidth: .infinity, minHeight: fixedHeight, maxHeight: fixedHeight)
                .contentShape(Rectangle())
                .onTapGesture { onTap?() }
                .id(artwork.id)
            ArtworkCaption(artwork: artwork)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Shows `visible` content while keeping the layout space of both phases (for fixed geometry).
struct PhaseLayers<Question: View, Reveal: View>: View {
    let isRevealing: Bool
    @ViewBuilder let question: Question
    @ViewBuilder let reveal: Reveal

    var body: some View {
        ZStack(alignment: .bottom) {
            question
                .opacity(isRevealing ? 0 : 1)
                .allowsHitTesting(!isRevealing)
                .accessibilityHidden(isRevealing)
            reveal
                .opacity(isRevealing ? 1 : 0)
                .allowsHitTesting(isRevealing)
                .accessibilityHidden(!isRevealing)
        }
    }
}

/// The reserved bottom action bar: always takes one answer-button height so nothing above jumps.
struct SessionBottomBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.answerButton)
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.s)
            .background(Tokens.Color.bgCanvas)
    }
}

/// The bottom bar's action. `.prominent` (gilt) is reserved for Place bid, Play today and
/// session-start CTAs; reveal "Next" buttons are `.secondary` (gilt stays ≤5% of pixels).
struct SessionActionButton: View {
    let title: String
    let identifier: String
    var style: ArtButtonStyle = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .artButtonStyle(style)
        .accessibilityIdentifier(identifier)
    }
}
