import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Subtle "soon" capsule.
struct SoonLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .artTextStyle(Tokens.Typography.provenance)
            .foregroundStyle(Tokens.Color.textSecondary)
            .padding(.horizontal, Tokens.Space.s)
            .padding(.vertical, Tokens.Space.xxs)
            .overlay(Capsule().strokeBorder(Tokens.Color.lineHairline, lineWidth: Tokens.Size.hairline))
    }
}

/// A mode tile: symbol, Fraunces name, one-line description; unavailable tiles are disabled.
struct ModeTile: View {
    let tile: ModeTileInfo
    var isHighlighted = false
    let action: () -> Void

    @Environment(\.app) private var app

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                if let artwork = HomeContent.tileArtwork(for: tile.mode, dataset: app.dataset) {
                    ArtworkDetail(artwork: artwork)
                        .aspectRatio(Tokens.Layout.tileDetailAspect, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous))
                }
                HStack {
                    Image(systemName: tile.symbol)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Tokens.Color.textSecondary)
                    Spacer(minLength: Tokens.Space.xs)
                    if !tile.isAvailable { SoonLabel(text: "Soon") }
                }
                Text(tile.title)
                    .artTextStyle(Tokens.Typography.titleArt)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(tile.blurb)
                    .artTextStyle(Tokens.Typography.label)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(Tokens.Space.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Tokens.Color.bgSurface, in: RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                    .strokeBorder(isHighlighted ? Tokens.Color.accentGilt : Tokens.Color.lineHairline,
                                  lineWidth: isHighlighted ? Tokens.Space.xxs : Tokens.Size.hairline))
            .opacity(tile.isAvailable ? 1 : Tokens.Layout.disabledTileOpacity)
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!tile.isAvailable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tile.isAvailable ? tile.title : "\(tile.title), coming soon")
        .accessibilityHint(isHighlighted ? "Suggested for you. \(tile.blurb)" : tile.blurb)
        .accessibilityIdentifier("mode.\(tile.mode.rawValue)")
    }
}
