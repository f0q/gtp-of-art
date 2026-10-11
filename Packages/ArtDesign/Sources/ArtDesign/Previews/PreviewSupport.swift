import CoreGraphics
import SwiftUI

// Specimen views for previews and future snapshot tests. They are ordinary views (compiled
// everywhere, so the CLT build checks them); `Previews.swift` wraps them in `#Preview`.

/// The four required preview variants (plan Part C7).
enum PreviewVariant: String, CaseIterable {
    case light, dark, ax5, reduceMotion
}

extension View {
    /// Applies a preview variant: appearance, AX5 Dynamic Type or forced Reduce Motion.
    func previewVariant(_ variant: PreviewVariant) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.Color.bgCanvas)
            .environment(\.colorScheme, variant == .light ? .light : .dark)
            .environment(\.dynamicTypeSize, variant == .ax5 ? .accessibility5 : .large)
            .environment(\.artReduceMotionOverride, variant == .reduceMotion ? true : nil)
    }
}

/// Procedurally drawn stand-in artwork (no bundled images in the design package).
enum PreviewArt {
    static func image(width: Int = 480, height: Int = 600) -> CGImage? {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let colors = [CGColor(srgbRed: 0.18, green: 0.24, blue: 0.36, alpha: 1),
                      CGColor(srgbRed: 0.78, green: 0.62, blue: 0.38, alpha: 1)] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
        }
        ctx.setFillColor(CGColor(srgbRed: 0.95, green: 0.9, blue: 0.8, alpha: 0.8))
        ctx.fillEllipse(in: CGRect(x: width / 3, y: height / 2, width: width / 3, height: width / 3))
        return ctx.makeImage()
    }

    static let pixelSize = CGSize(width: 480, height: 600)
}

struct PreviewArtwork: Identifiable {
    let id: Int
    let title: String
}

// MARK: - Specimens

struct TypographySpecimen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                Text("The Luminist").artTextStyle(Tokens.Typography.displayXL)
                Text("Daily Challenge").artTextStyle(Tokens.Typography.displayL)
                Text("Wheat Field with Cypresses").artTextStyle(Tokens.Typography.titleArt)
                Text(verbatim: "$57,000,000").artTextStyle(Tokens.Typography.priceHero)
                    .foregroundStyle(Tokens.Color.accentGilt)
                Text("Every price is approximate, shown with its sale year and source.")
                    .artTextStyle(Tokens.Typography.body)
                Text("Place bid").artTextStyle(Tokens.Typography.label)
                Text("Sold 1993 · Private sale · approx.").artTextStyle(Tokens.Typography.provenance)
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
            .foregroundStyle(Tokens.Color.textPrimary)
            .padding(Tokens.Space.l)
        }
    }
}

struct GlassSpecimen: View {
    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            HStack {
                Button { } label: {
                    Image(systemName: "xmark").frame(width: Tokens.Size.minTarget, height: Tokens.Size.minTarget)
                }
                .buttonStyle(.plain)
                .artGlass(Circle(), interactive: true)
                .accessibilityLabel(Text("Close"))
                Spacer()
                Text("Lot 3 of 10")
                    .artTextStyle(Tokens.Typography.label)
                    .padding(.horizontal, Tokens.Space.l)
                    .padding(.vertical, Tokens.Space.s)
                    .artGlass()
            }
            Spacer()
            Button("Place bid") { }.artButtonStyle(.prominent)
            Button("Skip") { }.artButtonStyle(.secondary)
        }
        .foregroundStyle(Tokens.Color.textPrimary)
        .padding(Tokens.Space.l)
    }
}

struct ArtworkFrameSpecimen: View {
    var body: some View {
        VStack(spacing: Tokens.Space.xl) {
            ArtworkFrame(image: PreviewArt.image(), pixelSize: PreviewArt.pixelSize,
                         placeholder: Tokens.Color.bgElevated, accessibilityLabel: Text("Stand-in artwork"))
            ArtworkFrame(image: nil, pixelSize: CGSize(width: 1600, height: 900),
                         placeholder: Tokens.Color.bgElevated)
        }
        .padding(Tokens.Space.xl)
    }
}

struct CardStackSpecimen: View {
    @State private var items = (1...6).map { PreviewArtwork(id: $0, title: "Study no. \($0)") }
    @State private var removed: [PreviewArtwork] = []
    @State private var controller = CardStackController()

    var body: some View {
        VStack(spacing: Tokens.Space.xl) {
            CardStack(items: items, controller: controller, onSwipe: { item, _ in
                removed.append(item)
                items.removeAll { $0.id == item.id }
            }, onUndo: {
                if let last = removed.popLast() { items.insert(last, at: 0) }
            }) { item in
                VStack(spacing: Tokens.Space.m) {
                    ArtworkFrame(image: PreviewArt.image(), pixelSize: PreviewArt.pixelSize,
                                 placeholder: Tokens.Color.bgElevated)
                    Text(item.title).artTextStyle(Tokens.Typography.titleArt)
                        .foregroundStyle(Tokens.Color.textPrimary)
                }
                .padding(Tokens.Space.l)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tokens.Color.bgSurface)
            }
            CardStackButtons(controller: controller)
        }
        .padding(.vertical, Tokens.Space.xl)
    }
}

struct LogSliderSpecimen: View {
    @State private var position = 480

    var body: some View {
        VStack(spacing: Tokens.Space.xl) {
            Text(LogPriceScale.label(forPosition: position))
                .artTextStyle(Tokens.Typography.priceHero)
                .foregroundStyle(Tokens.Color.accentGilt)
                .contentTransition(.numericText(value: Double(position)))
            LogSlider(position: $position)
        }
        .padding(Tokens.Space.l)
    }
}

struct HammerRevealSpecimen: View {
    @State private var reveal = HammerRevealDriver()
    @State private var chosen: Int?
    @Environment(\.artReduceMotion) private var reduceMotion
    private let options = [3_000_000.0, 8_500_000, 25_000_000, 82_500_000]

    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            RevealPrice(guess: chosen.map { options[$0] }, actual: 82_500_000, finalText: "$82.5M",
                        phase: reveal.phase)
                .artTextStyle(Tokens.Typography.priceHero)
                .foregroundStyle(Tokens.Color.accentGilt)
                .revealSettle(phase: reveal.phase)
            Text("Sold 1990 · Christie's NY · approx. incl. premium")
                .artTextStyle(Tokens.Typography.provenance)
                .foregroundStyle(Tokens.Color.textSecondary)
                .revealProvenance(phase: reveal.phase)
            ForEach(options.indices, id: \.self) { i in
                Button(LogPriceScale.format(options[i])) {
                    chosen = i
                    reveal.start(isHit: i == 3, reduceMotion: reduceMotion,
                                 announcement: "Sold for about 82 million dollars in 1990.")
                }
                .artButtonStyle(.option)
                .artOptionState(reveal.phase < .settle ? .normal : (i == 3 ? .correct : (chosen == i ? .normal : .incorrect)))
                .revealOption(isChosen: chosen == i && i != 3, phase: reveal.phase < .settle ? reveal.phase : .idle)
                .disabled(reveal.isLocked)
            }
            Button("Next") { reveal.reset(); chosen = nil }
                .artButtonStyle(.prominent)
                .revealNext(phase: reveal.phase)
        }
        .revealHaptics(reveal)
        .padding(Tokens.Space.l)
    }
}

struct ShareCardSpecimen: View {
    var body: some View {
        ShareCardView(artwork: PreviewArt.image(), artworkPixelSize: PreviewArt.pixelSize,
                      artworkPlaceholder: Tokens.Color.bgElevated, title: "Wheat Field with Cypresses",
                      subtitle: "Vincent van Gogh · 1889", headline: "8/10", headlineCaption: "Pick the price",
                      marks: [.hit, .hit, .close, .hit, .miss, .hit, .hit, .close, .hit, .miss])
    }
}
