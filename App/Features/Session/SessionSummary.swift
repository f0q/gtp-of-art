import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// What a finished session shows and shares.
struct SessionSummary: Equatable {
    var mode: GameMode
    /// The stat: "8/10", "Streak 14", "Average miss 2.4×".
    var headline: String
    /// Line under the stat: "Pick the price · 920 points".
    var caption: String
    /// Optional extra line ("Best: within 8% on …", "New personal best").
    var detail: String?
    var marks: [ShareMark]
    /// The artwork featured on the summary and the share card.
    var featured: Artwork?
    var isPersonalBest = false
    /// Replaces `caption` on the share card when set (e.g. the mastered categories).
    var shareCaption: String? = nil
    /// Plain-text share (the daily's emoji-free grid line), offered alongside the image.
    var shareText: String? = nil
}

/// Session summary: featured work, headline stat, marks, Play again (primary), Home, Share.
struct SessionSummaryView: View {
    let summary: SessionSummary
    let actions: SessionActions

    @Environment(\.app) private var app
    @Environment(\.colorScheme) private var colorScheme
    @State private var shareImage: ShareCardImage?
    @State private var sharePreview: Image?

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.Space.xl) {
                Text("Session complete")
                    .artTextStyle(Tokens.Typography.provenance)
                    .foregroundStyle(Tokens.Color.textSecondary)
                if let featured = summary.featured {
                    ArtworkImage(artwork: featured)
                        .containerRelativeFrame(.vertical) { length, _ in length * Tokens.Size.artMinHeightRatio }
                    ArtworkCaption(artwork: featured)
                }
                VStack(spacing: Tokens.Space.xs) {
                    Text(summary.headline)
                        .artTextStyle(Tokens.Typography.displayXL)
                        .monospacedDigit()
                        .foregroundStyle(Tokens.Color.accentGilt)
                        .accessibilityIdentifier("summary.headline")
                    Text(summary.caption)
                        .artTextStyle(Tokens.Typography.label)
                        .foregroundStyle(Tokens.Color.textSecondary)
                    if let detail = summary.detail {
                        Label(detail, systemImage: summary.isPersonalBest ? "rosette" : "scope")
                            .artTextStyle(Tokens.Typography.label)
                            .foregroundStyle(summary.isPersonalBest ? Tokens.Color.accentGilt : Tokens.Color.textPrimary)
                    }
                }
                .multilineTextAlignment(.center)
                marksRow
            }
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.xl)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) { buttons }
        .task(id: colorScheme) { await renderShareCard() }
    }

    @ViewBuilder
    private var marksRow: some View {
        if !summary.marks.isEmpty {
            HStack(spacing: Tokens.Space.xs) {
                ForEach(Array(summary.marks.suffix(10).enumerated()), id: \.offset) { _, mark in
                    Image(systemName: mark.symbol)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(mark == .miss ? Tokens.Color.textSecondary : Tokens.Color.accentGilt)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(summary.marks.map(\.label).joined(separator: ", "))
        }
    }

    private var buttons: some View {
        VStack(spacing: Tokens.Space.m) {
            SessionPrimaryButton(title: "Play again", identifier: "summary.playAgain", action: actions.playAgain)
            HStack(spacing: Tokens.Space.m) {
                Button(action: actions.close) {
                    Label("Home", systemImage: "house").frame(maxWidth: .infinity)
                }
                .artButtonStyle(.secondary)
                .accessibilityIdentifier("summary.home")
                if let shareImage, let sharePreview {
                    ShareLink(
                        item: shareImage,
                        preview: SharePreview(summary.headline, image: sharePreview)
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }
                    .artButtonStyle(.secondary)
                    .accessibilityIdentifier("summary.share")
                }
            }
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.bottom, Tokens.Space.s)
    }

    private func renderShareCard() async {
        var artworkImage: CGImage?
        if let featured = summary.featured,
            let request = ArtworkImageRequest.make(featured, .large, locator: app.dataset.images)
        {
            artworkImage = try? await app.imageLoader.image(for: request)
        }
        let card = ShareCardFactory.card(summary, image: artworkImage, locator: app.dataset)
        guard let cg = ShareCardRenderer.cgImage(card, colorScheme: colorScheme),
            let png = ShareCardRenderer.encodePNG(cg)
        else { return }
        shareImage = ShareCardImage(png: png)
        sharePreview = Image(decorative: cg, scale: Tokens.Size.shareCardScale)
    }
}
