import ArtCore
import ArtDesign
import SwiftUI

/// The reveal strip: the bid range with labelled decade ticks, nested tier brackets (≤2×, ≤5×,
/// ≤10×, each labelled) around the sale price, the player's bid, the sale-price pin dropping in,
/// and a legend for both markers.
struct BidRevealTrack: View {
    let bounds: ClosedRange<Int>
    let guessPosition: Int
    let actualMilli: Int
    let phase: RevealPhase

    @Environment(\.artReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Pin room above the track, then the bracket, then `bracketLabelMaxRows` label rows below it.
    @ScaledMetric(relativeTo: .footnote) private var trackHeight: CGFloat = Tokens.Space.xxxl + Tokens.Space.xxl
    @ScaledMetric(relativeTo: .footnote) private var rowHeight: CGFloat = Tokens.Space.l
    /// One line of decade labels (provenance style is footnote-relative).
    @ScaledMetric(relativeTo: .footnote) private var decadeRowHeight: CGFloat = Tokens.Space.l
    @State private var labelWidths: [Int: CGFloat] = [:]

    /// Widest first; each is drawn 120ms after the previous.
    private let brackets: [(tier: BidTier, label: String)] = [(.inTheRoom, "10×"), (.goodInstinct, "5×"), (.expertEye, "2×")]

    var body: some View {
        VStack(spacing: Tokens.Space.xs) {
            GeometryReader { geo in
                let width = geo.size.width
                let midY = Tokens.Space.xxl
                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(Tokens.Color.lineHairline)
                        .frame(width: width, height: Tokens.Space.xs)
                        .position(x: width / 2, y: midY)
                    ForEach(Array(brackets.enumerated()), id: \.offset) { index, bracket in
                        bracketView(bracket.tier, width: width, midY: midY)
                            .opacity(phase >= .settle ? 1 : 0)
                            .animation(reduceMotion ? ArtMotion.crossfade
                                       : ArtMotion.fast.delay(Double(index) * Tokens.Motion.Stagger.loose),
                                       value: phase >= .settle)
                    }
                    ForEach(labelPlacements(width: width), id: \.id) { placement in
                        bracketLabel(brackets[placement.id].label)
                            .position(x: placement.minX + (labelWidths[placement.id] ?? 0) / 2,
                                      y: midY + Tokens.Space.s + rowHeight * (CGFloat(placement.row) + 0.5))
                            .opacity(phase >= .settle ? 1 : 0)
                            .animation(reduceMotion ? ArtMotion.crossfade : ArtMotion.fast, value: phase >= .settle)
                    }
                    Circle()
                        .strokeBorder(Tokens.Color.textPrimary, lineWidth: Tokens.Space.xxs)
                        .frame(width: Tokens.Space.l, height: Tokens.Space.l)
                        .position(x: x(Double(guessPosition), width), y: midY)
                    Image(systemName: "mappin")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Tokens.Color.accentGilt)
                        .position(x: x(actualPosition, width), y: midY - Tokens.Space.m)
                        .offset(y: phase >= .roll || reduceMotion ? 0 : -Tokens.Space.xl)
                        .opacity(phase >= .roll ? 1 : 0)
                        .animation(reduceMotion ? ArtMotion.crossfade : ArtMotion.entrance, value: phase >= .roll)
                }
            }
            .frame(height: trackHeight)
            .background(alignment: .topLeading) { labelMeasurements }
            decadeLabels
            legend
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityText(guessPosition: guessPosition, actualMilli: actualMilli))
    }

    /// "Your bid 450 thousand dollars against the sale price 1.2 million dollars."
    static func accessibilityText(guessPosition: Int, actualMilli: Int) -> String {
        let actual = Double(actualMilli - LogPriceScale.baseMilli) / Double(LogPriceScale.milliPerPosition)
        let sale = LogPriceScale.format(LogPriceScale.price(forPosition: Int(actual.rounded())))
        return SpokenPrice.text(
            "Your bid \(LogPriceScale.label(forPosition: guessPosition)) against the sale price \(sale).")
    }

    /// Decade labels under the track. At accessibility sizes every other label is dropped so they
    /// never collide, and the first and last are pinned inside the edges so they are never clipped.
    private var decadeLabels: some View {
        let shown = typeSize.isAccessibilitySize ? LogPriceScale.thinnedDecades(decades) : decades
        return GeometryReader { geo in
            ForEach(shown, id: \.self) { p in
                Text(LogPriceScale.label(forPosition: p))
                    .artTextStyle(Tokens.Typography.provenance)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .fixedSize()
                    .frame(width: geo.size.width, alignment: alignment(for: p))
                    .offset(x: alignment(for: p) == .center ? x(Double(p), geo.size.width) - geo.size.width / 2 : 0)
                    .frame(height: geo.size.height)
            }
        }
        // Labels share the track width; past AX1 they would collide (the price above is full size).
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .frame(height: decadeRowHeight)
        .accessibilityHidden(true)
    }

    private func alignment(for p: Int) -> Alignment {
        if p == decades.first { return .leading }
        if p == decades.last { return .trailing }
        return .center
    }

    private var legend: some View {
        HStack(spacing: Tokens.Space.l) {
            Label {
                Text("Your bid")
            } icon: {
                Circle().strokeBorder(Tokens.Color.textPrimary, lineWidth: Tokens.Space.xxs)
                    .frame(width: Tokens.Space.m, height: Tokens.Space.m)
            }
            Label {
                Text("Sale price")
            } icon: {
                Image(systemName: "mappin").foregroundStyle(Tokens.Color.accentGilt)
            }
        }
        .artTextStyle(Tokens.Typography.provenance)
        .foregroundStyle(Tokens.Color.textSecondary)
    }

    private var decades: [Int] {
        Array(stride(from: bounds.lowerBound, through: bounds.upperBound, by: LogPriceScale.positionsPerDecade))
    }

    private var actualPosition: Double {
        Double(actualMilli - LogPriceScale.baseMilli) / Double(LogPriceScale.milliPerPosition)
    }

    private func x(_ position: Double, _ width: CGFloat) -> CGFloat {
        let span = Double(max(bounds.upperBound - bounds.lowerBound, 1))
        let t = (position - Double(bounds.lowerBound)) / span
        let inset = Tokens.Space.l
        return inset + CGFloat(min(max(t, 0), 1)) * (width - 2 * inset)
    }

    private func bracketView(_ tier: BidTier, width: CGFloat, midY: CGFloat) -> some View {
        let (left, right) = edges(tier, width: width)
        return RoundedRectangle(cornerRadius: Tokens.Space.xs, style: .continuous)
            .strokeBorder(Tokens.Color.accentGilt.opacity(tier == .expertEye ? 1 : Tokens.Motion.Reveal.dimOpacity),
                          lineWidth: Tokens.Space.xxs)
            .frame(width: max(right - left, Tokens.Space.xs), height: Tokens.Space.l)
            .position(x: (left + right) / 2, y: midY)
    }

    /// Bracket edges in track coordinates.
    private func edges(_ tier: BidTier, width: CGFloat) -> (CGFloat, CGFloat) {
        let reach = Double(tier.maxErrorMilli ?? 0) / Double(LogPriceScale.milliPerPosition)
        return (x(actualPosition - reach, width), x(actualPosition + reach, width))
    }

    /// Non-overlapping label positions from ArtDesign's `BracketLabelLayout` (rows stack downward).
    private func labelPlacements(width: CGFloat) -> [BracketLabelLayout.Placement] {
        let items = brackets.indices.compactMap { i -> BracketLabelLayout.Item? in
            guard let w = labelWidths[i] else { return nil }
            let (left, right) = edges(brackets[i].tier, width: width)
            return BracketLabelLayout.Item(id: i, left: left, right: right, labelWidth: w)
        }
        return BracketLabelLayout.place(items, trackWidth: width)
    }

    private func bracketLabel(_ text: String) -> some View {
        Text(text)
            .artTextStyle(Tokens.Typography.provenance)
            .foregroundStyle(Tokens.Color.textSecondary)
            .fixedSize()
    }

    /// Invisible copies of the labels, measured for the layout.
    private var labelMeasurements: some View {
        ZStack(alignment: .topLeading) {
            ForEach(brackets.indices, id: \.self) { i in
                bracketLabel(brackets[i].label)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { labelWidths[i] = $0 }
            }
        }
        .hidden()
        .accessibilityHidden(true)
    }
}
