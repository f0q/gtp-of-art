import SwiftUI

/// Shows an artwork the way a museum hangs it: aspect-fit (never cropped), a 2pt mat, square corners
/// and a picture-light shadow. Until the image is decoded, the frame holds its exact aspect ratio
/// filled with the dataset's dominant colour, so layout never jumps.
///
/// Never place glass or text over this view (AGENTS.md rule 4).
public struct ArtworkFrame: View {
    private let image: CGImage?
    private let pixelSize: CGSize
    private let placeholder: Color
    private let accessibilityLabel: Text?

    /// Creates a frame.
    /// - Parameters:
    ///   - image: The decoded image, or `nil` while loading.
    ///   - pixelSize: Pixel size from the dataset (`pixel_w`/`pixel_h`); defines the aspect ratio.
    ///   - placeholder: Dominant colour (`Color(datasetHex:)`) shown until the image arrives.
    ///   - accessibilityLabel: Alt text (≤140 chars). `nil` marks the image decorative.
    public init(image: CGImage?, pixelSize: CGSize, placeholder: Color, accessibilityLabel: Text? = nil) {
        self.image = image
        self.pixelSize = pixelSize
        self.placeholder = placeholder
        self.accessibilityLabel = accessibilityLabel
    }

    /// Convenience for a platform image (`UIImage` on iOS, `NSImage` on macOS).
    public init(platformImage: PlatformImage?, pixelSize: CGSize, placeholder: Color,
                accessibilityLabel: Text? = nil) {
        self.init(image: platformImage.flatMap(Self.cgImage(from:)), pixelSize: pixelSize,
                  placeholder: placeholder, accessibilityLabel: accessibilityLabel)
    }

    /// Width / height; falls back to 1 for degenerate sizes.
    var aspectRatio: CGFloat {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return 1 }
        return pixelSize.width / pixelSize.height
    }

    public var body: some View {
        content
            .aspectRatio(aspectRatio, contentMode: .fit)
            .padding(Tokens.Size.matWidth)
            .background(Tokens.Color.bgMat)
            .compositingGroup()
            .artShadow(Tokens.Elevation.artwork)
            .accessibilityElement(children: .ignore)
            .modifier(ArtworkAccessibility(label: accessibilityLabel))
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .transition(.opacity)
        } else {
            Rectangle().fill(placeholder)
        }
    }

    private static func cgImage(from image: PlatformImage) -> CGImage? {
        #if canImport(UIKit)
        image.cgImage
        #else
        image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }
}

/// Image trait + label, or hidden when decorative.
private struct ArtworkAccessibility: ViewModifier {
    let label: Text?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label).accessibilityAddTraits(.isImage)
        } else {
            content.accessibilityHidden(true)
        }
    }
}
