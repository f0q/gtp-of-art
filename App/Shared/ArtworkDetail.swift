import ArtCore
import ArtData
import ArtDesign
import SwiftUI

/// A painting detail: the artwork scaled up around its dataset `focus` point and clipped to the
/// frame (mode tiles, "See the clue"). Not used where the whole work must be seen.
struct ArtworkDetail: View {
    let artwork: Artwork
    /// Extra magnification over aspect-fill (1 = plain fill).
    var zoom: CGFloat = 1

    @Environment(\.app) private var app
    @State private var image: CGImage?

    var body: some View {
        GeometryReader { geo in
            let placeholder = app.dataset.images.placeholder(for: artwork, rendition: .small)
            let pixel = placeholder.pixelSize.map { CGSize(width: $0.width, height: $0.height) }
                ?? CGSize(width: 1, height: 1)
            let fill = max(geo.size.width / pixel.width, geo.size.height / pixel.height) * zoom
            let size = CGSize(width: pixel.width * fill, height: pixel.height * fill)
            let focus = CGPoint(x: CGFloat(artwork.image.focus.x) / 1000, y: CGFloat(artwork.image.focus.y) / 1000)
            let x = clamp(geo.size.width / 2 - focus.x * size.width, lower: geo.size.width - size.width)
            let y = clamp(geo.size.height / 2 - focus.y * size.height, lower: geo.size.height - size.height)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(datasetHex: placeholder.dominantHex) ?? Tokens.Color.bgElevated)
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: size.width, height: size.height)
                        .offset(x: x, y: y)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
        .task(id: artwork.id) {
            guard let request = ArtworkImageRequest.make(artwork, .large, locator: app.dataset.images) else { return }
            image = try? await app.imageLoader.image(for: request)
        }
    }

    /// Keeps the image covering the frame: offset in `lower…0`.
    private func clamp(_ value: CGFloat, lower: CGFloat) -> CGFloat {
        min(0, max(lower, value))
    }
}
