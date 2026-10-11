import ArtCore
import ArtData
import ArtDesign
import SwiftUI

/// One collected work: the artwork, its provenance line (ⓘ), image credit and your swipe.
struct CollectionDetailView: View {
    let artworkID: ArtworkID

    @Environment(\.app) private var app
    @Environment(ProfileModel.self) private var profile
    @State private var liked: Bool?

    var body: some View {
        ScrollView {
            if let artwork = app.dataset.artwork(artworkID) {
                VStack(alignment: .leading, spacing: Tokens.Space.l) {
                    ArtworkImage(artwork: artwork)
                        .frame(maxWidth: .infinity)
                    ArtworkCaption(artwork: artwork, alignment: .leading)
                    if let liked {
                        Label(liked ? "You kept this one" : "You passed on this one",
                              systemImage: liked ? "heart.fill" : "xmark")
                            .artTextStyle(Tokens.Typography.label)
                            .foregroundStyle(liked ? Tokens.Color.feedbackHit : Tokens.Color.textSecondary)
                            .accessibilityIdentifier("collection.swipeState")
                    }
                    if let record = artwork.gamePrice {
                        ProvenanceLine(artwork: artwork, record: record)
                    } else {
                        Text("No public sale price on record.")
                            .artTextStyle(Tokens.Typography.provenance)
                            .foregroundStyle(Tokens.Color.textSecondary)
                    }
                    Text(artwork.medium.display)
                        .artTextStyle(Tokens.Typography.body)
                        .foregroundStyle(Tokens.Color.textPrimary)
                    Text(artwork.image.attribution + " · " + artwork.image.licence)
                        .artTextStyle(Tokens.Typography.provenance)
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
                .padding(Tokens.Space.l)
            }
        }
        .background(Tokens.Color.bgCanvas.ignoresSafeArea())
        .navigationTitle(app.dataset.artwork(artworkID)?.title ?? "Artwork")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        let log = await profile.roundLog()
        liked = CollectionContent(records: log.records, pool: app.dataset.pool).swipes[artworkID]
    }
}
