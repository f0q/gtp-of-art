import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Builds the `ShareCardView` for a session summary (pure; snapshot-tested).
enum ShareCardFactory {
    static func card(_ summary: SessionSummary, image: CGImage?, locator dataset: any DatasetProviding)
        -> ShareCardView
    {
        let featured = summary.featured
        let placeholder = featured.map { dataset.images.placeholder(for: $0, rendition: .large) }
        let size = placeholder?.pixelSize.map { CGSize(width: $0.width, height: $0.height) }
            ?? ShareCardView.size
        return ShareCardView(
            artwork: image, artworkPixelSize: size,
            artworkPlaceholder: placeholder.flatMap { Color(datasetHex: $0.dominantHex) } ?? Tokens.Color.bgElevated,
            title: featured?.title ?? HomeContent.tile(for: summary.mode)?.title ?? AppInfo.wordmark,
            subtitle: featured.map { "\($0.artist.displayName) · \($0.date.display)" },
            headline: summary.headline, headlineCaption: summary.shareCaption ?? summary.caption, marks: Array(summary.marks.suffix(10)),
            wordmark: AppInfo.wordmark)
    }
}
