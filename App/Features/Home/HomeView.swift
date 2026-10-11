import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// The hub: date + profile button, Painting of the Day, Daily Challenge card, mode grid.
struct HomeView: View {
    @Environment(\.app) private var app
    @Environment(DayModel.self) private var day
    @Environment(Router.self) private var router
    @Environment(ProfileModel.self) private var profile
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                header
                if let artwork = HomeContent.paintingOfTheDay(on: day.today, dataset: app.dataset) {
                    PaintingOfTheDayView(artwork: artwork, maxArtworkHeight: viewportHeight * Tokens.Layout.heroArtworkFraction)
                }
                DailyHubCard()
                Text("Play")
                    .artTextStyle(Tokens.Typography.displayL)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                ModeGrid(tiles: HomeContent.tiles, columns: typeSize.isAccessibilitySize ? 1 : 2,
                         highlighted: profile.profile.prior?.highlightedMode) { mode in
                    router.start(mode)
                }
            }
            .padding(.horizontal, Tokens.Space.l)
            .padding(.bottom, Tokens.Space.xxl)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
        .background(Tokens.Color.bgCanvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Tokens.Space.m) {
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                Text(AppInfo.wordmark)
                    .artTextStyle(Tokens.Typography.displayL)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("home.title")
                Text(HomeContent.dateLine(day.today))
                    .artTextStyle(Tokens.Typography.provenance)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .accessibilityIdentifier("home.date")
            }
            Spacer(minLength: Tokens.Space.s)
            Button { router.showProfile() } label: {
                Image(systemName: "person.crop.circle")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .frame(width: Tokens.Size.minTarget, height: Tokens.Size.minTarget)
                    .artGlass(Circle(), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile and settings")
            .accessibilityIdentifier("home.profile")
        }
        .padding(.top, Tokens.Space.s)
    }
}

/// Painting of the Day hero: the work hung on the canvas, title and artist below.
struct PaintingOfTheDayView: View {
    let artwork: Artwork
    /// Tallest the artwork may be (aspect-fit: landscape works take the full width instead).
    let maxArtworkHeight: CGFloat

    var body: some View {
        VStack(spacing: Tokens.Space.m) {
            Text("Painting of the Day")
                .artTextStyle(Tokens.Typography.provenance)
                .foregroundStyle(Tokens.Color.textSecondary)
            ArtworkImage(artwork: artwork)
                .frame(maxHeight: maxArtworkHeight > 0 ? maxArtworkHeight : nil)
            ArtworkCaption(artwork: artwork)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("home.hero")
    }
}

/// The mode tiles in rows (not lazy: five tiles, and every tile must exist for VoiceOver and UI tests).
struct ModeGrid: View {
    let tiles: [ModeTileInfo]
    let columns: Int
    var highlighted: GameMode? = nil
    let start: (GameMode) -> Void

    var body: some View {
        let rows = stride(from: 0, to: tiles.count, by: columns).map { Array(tiles[$0..<min($0 + columns, tiles.count)]) }
        VStack(spacing: Tokens.Space.m) {
            ForEach(rows, id: \.first?.id) { row in
                HStack(alignment: .top, spacing: Tokens.Space.m) {
                    ForEach(row) { tile in
                        ModeTile(tile: tile, isHighlighted: tile.mode == highlighted) { start(tile.mode) }
                    }
                    if row.count < columns {
                        ForEach(0..<(columns - row.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
