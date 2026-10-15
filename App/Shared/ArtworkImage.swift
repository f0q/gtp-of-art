import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// The image request for an artwork rendition (decoded at the file's native size), shared by views
/// and prefetching so both hit the same cache entry.
nonisolated enum ArtworkImageRequest {
    static func make(_ artwork: Artwork, _ rendition: ImageRendition, locator: ImageLocator) -> ImageLoader.Request? {
        guard let url = locator.url(for: artwork, rendition: rendition),
            let size = locator.pixelSize(for: artwork, rendition: rendition)
        else { return nil }
        return ImageLoader.Request(url: url, maxPixelSize: max(size.width, size.height))
    }
}

/// An artwork in its `ArtworkFrame`, loaded through `ImageLoader`, labelled with the dataset alt text.
struct ArtworkImage: View {
    let artwork: Artwork
    var rendition: ImageRendition = .large
    var decorative = false

    @Environment(\.app) private var app
    @State private var image: CGImage?
    @State private var loadedID: ArtworkID?

    var body: some View {
        let placeholder = app.dataset.images.placeholder(for: artwork, rendition: rendition)
        let size = placeholder.pixelSize.map { CGSize(width: $0.width, height: $0.height) } ?? CGSize(width: 1, height: 1)
        ArtworkFrame(
            image: loadedID == artwork.id ? image : nil, pixelSize: size,
            placeholder: Color(datasetHex: placeholder.dominantHex) ?? Tokens.Color.bgElevated,
            accessibilityLabel: decorative ? nil : Text(Self.accessibilityText(artwork, altText: placeholder.altText)))
            .task(id: artwork.id) { await load() }
    }

    /// The dataset alt text, then title, artist and date: "A woman in a straw hat… Title, Artist, 1874."
    static func accessibilityText(_ artwork: Artwork, altText alt: String) -> String {
        let trimmed = alt.trimmingCharacters(in: .whitespaces)
        let sentence = trimmed.isEmpty || trimmed.hasSuffix(".") ? trimmed : trimmed + "."
        let head = sentence.isEmpty ? "" : sentence + " "
        return "\(head)\(artwork.title), \(artwork.artist.displayName), \(artwork.date.display)."
    }

    private func load() async {
        guard let request = ArtworkImageRequest.make(artwork, rendition, locator: app.dataset.images) else { return }
        let id = artwork.id
        if let decoded = try? await app.imageLoader.image(for: request), !Task.isCancelled {
            image = decoded
            loadedID = id
        }
    }
}

extension AppEnvironment {
    /// Decodes upcoming artworks in the background so the next round appears instantly.
    func prefetch(_ artworks: [Artwork], rendition: ImageRendition = .large) {
        let requests = artworks.compactMap { ArtworkImageRequest.make($0, rendition, locator: dataset.images) }
        guard !requests.isEmpty else { return }
        let loader = imageLoader
        Task { await loader.prefetch(requests) }
    }
}

/// Title (Fraunces italic) and "Artist · date" under an artwork.
struct ArtworkCaption: View {
    let artwork: Artwork
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: Tokens.Space.xxs) {
            Text(artwork.title)
                .artTextStyle(Tokens.Typography.titleArt)
                .foregroundStyle(Tokens.Color.textPrimary)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
            Text("\(artwork.artist.displayName) · \(artwork.date.display)")
                .artTextStyle(Tokens.Typography.provenance)
                .foregroundStyle(Tokens.Color.textSecondary)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
