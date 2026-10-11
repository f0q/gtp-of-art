import ArtCore
import ArtData
import ArtDesign
import SwiftUI

/// Salon-hang templates in unit coordinates of a 4:3 wall (pure; one template per count 1…7).
nonisolated enum SalonLayout {
    static let aspect: CGFloat = 4 / 3
    /// Where un-hung works wait (stacked like the swipe deck).
    static let pile = CGRect(x: 0.3, y: 0.15, width: 0.4, height: 0.7)

    private static let corners: [CGRect] = [
        CGRect(x: 0.04, y: 0.06, width: 0.27, height: 0.42), CGRect(x: 0.69, y: 0.06, width: 0.27, height: 0.42),
        CGRect(x: 0.04, y: 0.52, width: 0.27, height: 0.42), CGRect(x: 0.69, y: 0.52, width: 0.27, height: 0.42),
    ]

    static func slots(count: Int) -> [CGRect] {
        switch count {
        case ...0: return []
        case 1: return [CGRect(x: 0.2, y: 0.08, width: 0.6, height: 0.84)]
        case 2: return [CGRect(x: 0.06, y: 0.12, width: 0.42, height: 0.76), CGRect(x: 0.52, y: 0.12, width: 0.42, height: 0.76)]
        case 3:
            return [CGRect(x: 0.33, y: 0.06, width: 0.34, height: 0.88), CGRect(x: 0.04, y: 0.18, width: 0.26, height: 0.64),
                    CGRect(x: 0.70, y: 0.18, width: 0.26, height: 0.64)]
        case 4:
            return [CGRect(x: 0.04, y: 0.06, width: 0.44, height: 0.42), CGRect(x: 0.52, y: 0.06, width: 0.44, height: 0.42),
                    CGRect(x: 0.04, y: 0.52, width: 0.44, height: 0.42), CGRect(x: 0.52, y: 0.52, width: 0.44, height: 0.42)]
        case 5: return [CGRect(x: 0.34, y: 0.06, width: 0.32, height: 0.88)] + corners
        case 6:
            return [CGRect(x: 0.34, y: 0.04, width: 0.32, height: 0.56), CGRect(x: 0.38, y: 0.64, width: 0.24, height: 0.32)]
                + corners
        default:
            return [CGRect(x: 0.34, y: 0.04, width: 0.32, height: 0.56), CGRect(x: 0.34, y: 0.64, width: 0.15, height: 0.32),
                    CGRect(x: 0.51, y: 0.64, width: 0.15, height: 0.32)] + corners
        }
    }

    /// A unit rect scaled into `size`.
    static func frame(_ unit: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: unit.minX * size.width, y: unit.minY * size.height,
               width: unit.width * size.width, height: unit.height * size.height)
    }

    /// Small deterministic tilt for works still in the pile (degrees).
    static func pileTilt(_ index: Int) -> Double { Double((index % 5) - 2) * 2 }
}

/// "Your Salon Wall": liked works fly from a pile into a salon hang with `matchedGeometryEffect`.
/// The first `hung` works are on the wall; the rest wait in the pile.
struct SalonWall: View {
    let works: [Artwork]
    let hung: Int

    @Namespace private var wall

    var body: some View {
        GeometryReader { geo in
            let slots = SalonLayout.slots(count: works.count)
            ZStack(alignment: .topLeading) {
                anchor("pile", SalonLayout.frame(SalonLayout.pile, in: geo.size))
                ForEach(Array(slots.enumerated()), id: \.offset) { i, unit in
                    anchor("slot\(i)", SalonLayout.frame(unit, in: geo.size))
                }
                ForEach(Array(works.enumerated()), id: \.element.id) { i, work in
                    let isHung = i < hung
                    ArtworkImage(artwork: work, rendition: .small, decorative: true)
                        .matchedGeometryEffect(id: isHung ? "slot\(i)" : "pile", in: wall, isSource: false)
                        .rotationEffect(.degrees(isHung ? 0 : SalonLayout.pileTilt(i)))
                        .zIndex(isHung ? Double(i) : Double(works.count + i))
                }
            }
        }
        .aspectRatio(SalonLayout.aspect, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("taste.wall")
    }

    private func anchor(_ id: String, _ rect: CGRect) -> some View {
        Color.clear
            .frame(width: rect.width, height: rect.height)
            .matchedGeometryEffect(id: id, in: wall, isSource: true)
            .padding(.leading, rect.minX)
            .padding(.top, rect.minY)
    }

    private var accessibilityText: String {
        guard !works.isEmpty else { return "Your salon wall is empty." }
        let titles = works.map { "\($0.title) by \($0.artist.displayName)" }.joined(separator: "; ")
        return "Your salon wall: \(titles)."
    }
}

/// The same hang drawn from already-decoded images (share cards cannot load asynchronously).
struct StaticSalonWall: View {
    struct Piece {
        let image: CGImage?
        let pixelSize: CGSize
        let placeholder: Color
    }

    let pieces: [Piece]

    var body: some View {
        GeometryReader { geo in
            let slots = SalonLayout.slots(count: pieces.count)
            ZStack(alignment: .topLeading) {
                ForEach(Array(zip(pieces.indices, slots)), id: \.0) { i, unit in
                    let rect = SalonLayout.frame(unit, in: geo.size)
                    ArtworkFrame(image: pieces[i].image, pixelSize: pieces[i].pixelSize, placeholder: pieces[i].placeholder)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
        }
        .aspectRatio(SalonLayout.aspect, contentMode: .fit)
    }
}
