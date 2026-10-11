import ArtCore
import ArtData
import ArtDesign
import SwiftUI

/// Share card formats: 1080×1350 feed and 1080×1920 story (rendered at 3×).
enum TasteShareFormat: CaseIterable {
    case feed, story

    var size: CGSize {
        switch self {
        case .feed: ShareCardView.size
        case .story: CGSize(width: Tokens.Size.shareCardWidth, height: Tokens.Size.shareCardWidth * 16 / 9)
        }
    }
}

/// Taste share card: salon wall, archetype, pigment bars and edition. No personal data, no glass;
/// rarity labelled "estimated", prices "approx.".
struct TasteShareCard: View {
    let reading: TasteReading
    let wall: [StaticSalonWall.Piece]
    let format: TasteShareFormat

    /// The wall's explicit size: full content width, capped in height, at the salon aspect.
    private var wallSize: CGSize {
        let width = format.size.width - 2 * Tokens.Space.l
        let height = min(width / SalonLayout.aspect, format.size.height * (format == .story ? 0.3 : 0.2))
        return CGSize(width: height * SalonLayout.aspect, height: height)
    }

    var body: some View {
        VStack(spacing: format == .story ? Tokens.Space.xl : Tokens.Space.m) {
            Text("My Salon Wall")
                .artTextStyle(Tokens.Typography.provenance)
                .foregroundStyle(Tokens.Color.textSecondary)
            StaticSalonWall(pieces: wall)
                .frame(width: wallSize.width, height: wallSize.height)
            VStack(spacing: Tokens.Space.xxs) {
                Text(reading.archetype.name)
                    .artTextStyle(format == .story ? Tokens.Typography.displayXL : Tokens.Typography.displayL)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if format == .story {
                    Text(reading.archetype.line)
                        .artTextStyle(Tokens.Typography.body)
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            VStack(spacing: format == .story ? Tokens.Space.m : Tokens.Space.xxs) {
                ForEach(TasteAxis.allCases, id: \.self) { axis in
                    PigmentBar(axis: axis, value: axis.value(reading.report.axes), stops: axis.stops(from: reading.swatches),
                               compact: format == .feed)
                }
            }
            if let edition = reading.edition {
                HStack(spacing: Tokens.Space.m) {
                    if format == .story {
                        EditionGrid(lit: edition)
                    }
                    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                        Text(TasteCopy.edition(edition))
                            .artTextStyle(Tokens.Typography.label)
                            .monospacedDigit()
                            .foregroundStyle(Tokens.Color.accentGilt)
                        Text("Rarity estimated")
                            .artTextStyle(Tokens.Typography.provenance)
                            .foregroundStyle(Tokens.Color.textSecondary)
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline) {
                Text(AppInfo.wordmark)
                    .artTextStyle(Tokens.Typography.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(Tokens.Color.textPrimary)
                Spacer()
                Text("Taste estimated · Prices approx.")
                    .artTextStyle(Tokens.Typography.provenance)
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
        }
        .padding(Tokens.Space.l)
        .frame(width: format.size.width, height: format.size.height)
        .background(Tokens.Color.bgCanvas)
    }
}

extension ShareCardFactory {
    /// Wall pieces for a taste card (images already decoded, in wall order; missing ones use the
    /// dominant colour).
    static func tastePieces(_ works: [Artwork], images: [ArtworkID: CGImage], dataset: any DatasetProviding)
        -> [StaticSalonWall.Piece]
    {
        works.map { work in
            let placeholder = dataset.images.placeholder(for: work, rendition: .small)
            let size = placeholder.pixelSize.map { CGSize(width: $0.width, height: $0.height) } ?? CGSize(width: 1, height: 1)
            return StaticSalonWall.Piece(
                image: images[work.id], pixelSize: size,
                placeholder: Color(datasetHex: placeholder.dominantHex) ?? Tokens.Color.bgElevated)
        }
    }

    /// The taste share card (pure; snapshot-tested).
    static func taste(_ reading: TasteReading, images: [ArtworkID: CGImage], dataset: any DatasetProviding,
                      format: TasteShareFormat) -> TasteShareCard
    {
        TasteShareCard(
            reading: reading, wall: tastePieces(reading.session?.wall ?? [], images: images, dataset: dataset),
            format: format)
    }
}
