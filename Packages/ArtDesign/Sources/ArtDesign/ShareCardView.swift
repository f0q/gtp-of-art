import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// One round mark on a share card. Distinct shapes so results never rely on colour alone.
nonisolated public enum ShareMark: Sendable, Equatable {
    /// Correct / within 2× — filled diamond.
    case hit
    /// Close — outlined diamond.
    case close
    /// Miss — outlined square.
    case miss

    /// SF Symbol for this mark (distinct shapes: filled diamond, outlined diamond, square).
    public var symbol: String {
        switch self {
        case .hit: "diamond.fill"
        case .close: "diamond"
        case .miss: "square"
        }
    }

    /// Spoken name for VoiceOver and text shares ("hit", "close", "miss").
    public var label: String {
        switch self {
        case .hit: "hit"
        case .close: "close"
        case .miss: "miss"
        }
    }
}

/// The 360×450pt share card (rendered at 3× = 1080×1350px): artwork, title, headline stat, marks
/// row, wordmark and the "Prices approx." footer. Pure SwiftUI: no glass, materials, AsyncImage or
/// UIKit, so `ImageRenderer` output is deterministic and snapshot-testable.
public struct ShareCardView: View {
    private let artwork: CGImage?
    private let artworkPixelSize: CGSize
    private let artworkPlaceholder: Color
    private let title: String
    private let subtitle: String?
    private let headline: String
    private let headlineCaption: String?
    private let marks: [ShareMark]
    private let wordmark: String
    private let footer: String

    /// Creates a share card.
    /// - Parameters:
    ///   - artwork: Decoded artwork (already loaded; the renderer cannot wait for async images).
    ///   - artworkPixelSize: Pixel size for the aspect ratio.
    ///   - artworkPlaceholder: Dominant colour if `artwork` is nil.
    ///   - title: Artwork title (Fraunces italic).
    ///   - subtitle: Artist and year.
    ///   - headline: The stat, e.g. "8/10", "Streak 14", "Average miss 2.4×".
    ///   - headlineCaption: Optional line under the stat, e.g. "Pick the price".
    ///   - marks: Up to 10 round marks.
    ///   - wordmark: App name ("GTP of Art").
    ///   - footer: Honesty footer; keep "Prices approx." in it.
    public init(artwork: CGImage?, artworkPixelSize: CGSize, artworkPlaceholder: Color, title: String,
                subtitle: String? = nil, headline: String, headlineCaption: String? = nil,
                marks: [ShareMark] = [], wordmark: String = "GTP of Art", footer: String = "Prices approx.") {
        self.artwork = artwork
        self.artworkPixelSize = artworkPixelSize
        self.artworkPlaceholder = artworkPlaceholder
        self.title = title
        self.subtitle = subtitle
        self.headline = headline
        self.headlineCaption = headlineCaption
        self.marks = marks
        self.wordmark = wordmark
        self.footer = footer
    }

    /// Layout size in points.
    public static let size = CGSize(width: Tokens.Size.shareCardWidth, height: Tokens.Size.shareCardHeight)

    public var body: some View {
        VStack(spacing: Tokens.Space.l) {
            ArtworkFrame(image: artwork, pixelSize: artworkPixelSize, placeholder: artworkPlaceholder)
                .frame(maxWidth: .infinity, maxHeight: Self.size.height * 0.5)

            VStack(spacing: Tokens.Space.xs) {
                Text(title)
                    .artTextStyle(Tokens.Typography.titleArt)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle)
                        .artTextStyle(Tokens.Typography.provenance)
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .lineLimit(1)
                }
            }

            VStack(spacing: Tokens.Space.xxs) {
                Text(headline)
                    .artTextStyle(Tokens.Typography.displayL)
                    .foregroundStyle(Tokens.Color.accentGilt)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let headlineCaption {
                    Text(headlineCaption)
                        .artTextStyle(Tokens.Typography.label)
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
            }

            if !marks.isEmpty {
                HStack(spacing: Tokens.Space.xs) {
                    ForEach(Array(marks.prefix(10).enumerated()), id: \.offset) { _, mark in
                        Image(systemName: mark.symbol)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(mark == .miss ? Tokens.Color.textSecondary : Tokens.Color.accentGilt)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(Text(marks.map(\.label).joined(separator: ", ")))
            }

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline) {
                Text(wordmark)
                    .artTextStyle(Tokens.Typography.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(Tokens.Color.textPrimary)
                Spacer()
                Text(footer)
                    .artTextStyle(Tokens.Typography.provenance)
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
        }
        .padding(Tokens.Space.xl)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Tokens.Color.bgCanvas)
    }
}

/// Renders share cards with `ImageRenderer` at 3× (1080×1350 for a 360×450 card).
///
/// Appearance: share cards default to dark (Salon Noir is the brand look and reads best in feeds).
/// To follow the viewer's appearance instead, pass `@Environment(\.colorScheme)` as `colorScheme`.
/// Both appearances use the same tokens and meet 4.5:1.
public enum ShareCardRenderer {
    /// Appearance used when the caller does not pass one.
    public static let defaultColorScheme: ColorScheme = .dark

    /// Renders any view at the share-card size into a `CGImage`.
    /// Dynamic Type is pinned to `.large` so output is deterministic; appearance defaults to dark.
    public static func cgImage<V: View>(_ view: V, colorScheme: ColorScheme = ShareCardRenderer.defaultColorScheme,
                                        size: CGSize = ShareCardView.size) -> CGImage? {
        ArtFonts.register()
        let renderer = ImageRenderer(content: prepared(view, colorScheme: colorScheme, size: size))
        renderer.scale = Tokens.Size.shareCardScale
        renderer.isOpaque = true
        return renderer.cgImage
    }

    /// Renders into the platform image type (`UIImage` on iOS, `NSImage` on macOS).
    public static func platformImage<V: View>(_ view: V, colorScheme: ColorScheme = ShareCardRenderer.defaultColorScheme,
                                              size: CGSize = ShareCardView.size) -> PlatformImage? {
        ArtFonts.register()
        let renderer = ImageRenderer(content: prepared(view, colorScheme: colorScheme, size: size))
        renderer.scale = Tokens.Size.shareCardScale
        renderer.isOpaque = true
        #if canImport(UIKit)
        return renderer.uiImage
        #else
        return renderer.nsImage
        #endif
    }

    /// PNG bytes for `ShareLink` (see `ShareCardImage`).
    public static func pngData<V: View>(_ view: V, colorScheme: ColorScheme = ShareCardRenderer.defaultColorScheme,
                                        size: CGSize = ShareCardView.size) -> Data? {
        guard let image = cgImage(view, colorScheme: colorScheme, size: size) else { return nil }
        return encodePNG(image)
    }

    /// Encodes a CGImage as PNG with ImageIO (works on iOS and macOS).
    nonisolated public static func encodePNG(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func prepared<V: View>(_ view: V, colorScheme: ColorScheme, size: CGSize) -> some View {
        view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, colorScheme)
            .environment(\.dynamicTypeSize, .large)
    }
}

/// A rendered share card for `ShareLink(item:preview:)`.
nonisolated public struct ShareCardImage: Transferable, Sendable {
    /// PNG bytes.
    public let png: Data

    /// Wraps PNG data.
    public init(png: Data) { self.png = png }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.png }
    }
}
