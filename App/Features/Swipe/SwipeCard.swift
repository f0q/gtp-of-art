import ArtCore
import ArtData
import ArtDesign
import SwiftUI

/// One card: the artwork is the hero (aspect-fit, never cropped, 2pt mat + picture-light shadow),
/// with title and artist directly below. Never a price.
///
/// Landscape works fill the card width minus `Space.l`; portrait works fill the available height,
/// capped at `maxArtworkHeight` (the screen's `Tokens.Layout.artworkHeightFraction`). The card hugs
/// its content but never gets shorter than a card holding the tallest allowed image, so the stack
/// does not jump between landscape and portrait works.
struct SwipeCard: View {
    let artwork: Artwork
    /// Tallest the image may be (screen height × `Tokens.Layout.artworkHeightFraction`).
    let maxArtworkHeight: CGFloat

    @Environment(\.app) private var app
    /// Room kept for a two-line title + artist line under the image.
    @ScaledMetric(relativeTo: .title2) private var captionReserve = Tokens.Space.xxxl + Tokens.Space.l

    var body: some View {
        GeometryReader { geo in
            let layout = SwipeCardLayout(
                container: geo.size, aspect: aspect, maxArtworkHeight: maxArtworkHeight,
                captionReserve: captionReserve)
            VStack(spacing: Tokens.Space.m) {
                ArtworkImage(artwork: artwork)
                    .frame(width: layout.image.width, height: layout.image.height)
                ArtworkCaption(artwork: artwork)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(Tokens.Space.l)
            .frame(width: geo.size.width)
            .frame(minHeight: layout.minCardHeight)
            .background(Tokens.Color.bgSurface, in: RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                    .strokeBorder(Tokens.Color.lineHairline, lineWidth: Tokens.Size.hairline)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
    }

    /// Width ÷ height of the large rendition.
    private var aspect: CGFloat {
        CGFloat(app.dataset.images.placeholder(for: artwork, rendition: .large).pixelSize?.aspectRatio ?? 1)
    }
}

/// Pure sizing for `SwipeCard` (unit-tested).
nonisolated struct SwipeCardLayout: Equatable {
    /// Image frame (aspect-fit).
    let image: CGSize
    /// Height of a card holding the tallest allowed image.
    let minCardHeight: CGFloat

    init(container: CGSize, aspect: CGFloat, maxArtworkHeight: CGFloat, captionReserve: CGFloat) {
        let inset = Tokens.Space.l
        let chrome = 2 * inset + Tokens.Space.m + captionReserve
        let maxWidth = max(container.width - 2 * inset, 1)
        let maxHeight = max(min(maxArtworkHeight, container.height - chrome), 1)
        let a = aspect > 0 ? aspect : 1
        var size = CGSize(width: maxWidth, height: maxWidth / a)
        if size.height > maxHeight { size = CGSize(width: maxHeight * a, height: maxHeight) }
        image = size
        minCardHeight = min(maxHeight + chrome, container.height)
    }
}

/// Twenty dots: swiped, current (ring), upcoming.
struct SwipeProgressDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            ForEach(1...max(total, 1), id: \.self) { n in
                Circle()
                    .fill(n < current ? Tokens.Color.textSecondary : Color.clear)
                    .overlay {
                        Circle().strokeBorder(
                            n == current ? Tokens.Color.textPrimary : Tokens.Color.lineHairline,
                            lineWidth: n == current ? Tokens.Space.xxs : Tokens.Size.hairline * 2)
                    }
                    .frame(width: Tokens.Space.s, height: Tokens.Space.s)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Card \(current) of \(total)")
        .accessibilityIdentifier("swipe.progress")
    }
}

/// Swipe-up / "Details": the work's label without any price.
struct SwipeDetailSheet: View {
    let artwork: Artwork
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.l) {
                    ArtworkImage(artwork: artwork)
                        .frame(maxWidth: .infinity)
                    ArtworkCaption(artwork: artwork, alignment: .leading)
                    Text(artwork.image.altText)
                        .artTextStyle(Tokens.Typography.body)
                        .foregroundStyle(Tokens.Color.textPrimary)
                    LabeledContent("Medium", value: artwork.medium.display)
                        .artTextStyle(Tokens.Typography.label)
                    Text(artwork.image.attribution)
                        .artTextStyle(Tokens.Typography.provenance)
                        .foregroundStyle(Tokens.Color.textSecondary)
                    Text("Prices stay hidden until your taste is revealed.")
                        .artTextStyle(Tokens.Typography.provenance)
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
                .padding(Tokens.Space.l)
            }
            .background(Tokens.Color.bgCanvas)
            .navigationTitle("About this work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
