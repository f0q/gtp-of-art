import ArtCore
import ArtData
import ArtDesign
import SwiftUI

/// Collection: a grid of every work seen in any mode, with the discovered count.
struct CollectionView: View {
    @Environment(\.app) private var app
    @Environment(ProfileModel.self) private var profile
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var content: CollectionContent?

    /// Injected content (snapshots); otherwise loaded from the round history.
    var contentOverride: CollectionContent?

    private var shown: CollectionContent? { contentOverride ?? content }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.l) {
                if let shown {
                    header(shown)
                    if shown.seen.isEmpty { empty } else { grid(shown) }
                }
            }
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.l)
        }
        .background(Tokens.Color.bgCanvas.ignoresSafeArea())
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func header(_ c: CollectionContent) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(c.header)
                .artTextStyle(Tokens.Typography.displayL)
                .monospacedDigit()
                .foregroundStyle(Tokens.Color.accentGilt)
                .accessibilityIdentifier("collection.count")
            Text("Works you've seen, in any mode")
                .artTextStyle(Tokens.Typography.provenance)
                .foregroundStyle(Tokens.Color.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var empty: some View {
        Text("Play any mode and every work you meet joins your collection.")
            .artTextStyle(Tokens.Typography.body)
            .foregroundStyle(Tokens.Color.textSecondary)
            .accessibilityIdentifier("collection.empty")
    }

    private func grid(_ c: CollectionContent) -> some View {
        let columns = typeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: Tokens.Space.l)]
            : Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.l), count: 3)
        return LazyVGrid(columns: columns, alignment: .center, spacing: Tokens.Space.l) {
            ForEach(c.seen, id: \.self) { id in
                if let artwork = app.dataset.artwork(id) {
                    NavigationLink(value: Route.collectionArtwork(id)) {
                        CollectionCell(artwork: artwork, liked: c.swipes[id])
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("collection.item.\(id.rawValue)")
                }
            }
        }
        .accessibilityIdentifier("collection.grid")
    }

    private func load() async {
        guard contentOverride == nil else { return }
        let log = await profile.roundLog()
        content = CollectionContent(records: log.records, pool: app.dataset.pool)
    }
}

/// Thumbnail with the kept/passed mark underneath (never over the artwork).
struct CollectionCell: View {
    let artwork: Artwork
    let liked: Bool?

    var body: some View {
        VStack(spacing: Tokens.Space.xs) {
            ArtworkImage(artwork: artwork, rendition: .small, decorative: true)
                .frame(maxWidth: .infinity, minHeight: Tokens.Size.swipeButton, maxHeight: Tokens.Size.swipeButton * 2)
            HStack(spacing: Tokens.Space.xxs) {
                if let liked {
                    Image(systemName: liked ? "heart.fill" : "xmark")
                        .foregroundStyle(liked ? Tokens.Color.feedbackHit : Tokens.Color.textSecondary)
                }
                Text(artwork.title)
                    .lineLimit(1)
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
            .artTextStyle(Tokens.Typography.provenance)
        }
        .frame(minHeight: Tokens.Size.minTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    private var label: String {
        let state = liked.map { $0 ? ", kept" : ", passed" } ?? ""
        return "\(artwork.title), \(artwork.artist.displayName)\(state)"
    }
}
