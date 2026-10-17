import ArtCore
import ArtDesign
import SwiftUI

/// The reveal strip: the bid range with labelled decade ticks, nested tier brackets (≤2×, ≤5×,
/// ≤10×) around the sale price, the player's bid, the sale-price pin dropping in, and a legend for
/// the markers and the brackets.
///
/// Bracket labels live in a legend row (a nested-swatch per tier, innermost first) rather than on
/// the track: on the track the three labels crowd one another whenever the brackets are narrow, and
/// a legend never overlaps at any width.
struct BidRevealTrack: View {
    let bounds: ClosedRange<Int>
    let guessPosition: Int
    let actualMilli: Int
    let phase: RevealPhase

    @Environment(\.artReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Pin room above the track (`midY`), then half a bracket and a small margin below it.
    private let trackHeight: CGFloat = Tokens.Space.xxxl
    /// One line of decade labels (provenance style is footnote-relative).
    @ScaledMetric(relativeTo: .footnote) private var decadeRowHeight: CGFloat = Tokens.Space.l

    /// Widest first; each is drawn 120ms after the previous.
    private let brackets: [(tier: BidTier, label: String)] = [(.inTheRoom, "≤10×"), (.goodInstinct, "≤5×"), (.expertEye, "≤2×")]
    /// Legend swatch widths, innermost (≤2×) first, growing like the nested brackets.
    private let swatchWidths: [CGFloat] = [Tokens.Space.m, Tokens.Space.l, Tokens.Space.xl]

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
            decadeLabels
            legend
            bracketLegend
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
            .strokeBorder(bracketColor(tier), lineWidth: Tokens.Space.xxs)
            .frame(width: max(right - left, Tokens.Space.xs), height: Tokens.Space.l)
            .position(x: (left + right) / 2, y: midY)
    }

    /// Bracket edges in track coordinates.
    private func edges(_ tier: BidTier, width: CGFloat) -> (CGFloat, CGFloat) {
        let reach = Double(tier.maxErrorMilli ?? 0) / Double(LogPriceScale.milliPerPosition)
        return (x(actualPosition - reach, width), x(actualPosition + reach, width))
    }

    /// "▭ ≤2×  ▭ ≤5×  ▭ ≤10×": one swatch per bracket, innermost first, styled like its bracket
    /// (the ≤2× bracket at full gilt, the wider two dimmed) and growing like the nesting. Fades in
    /// with the brackets.
    private var bracketLegend: some View {
        HStack(spacing: Tokens.Space.l) {
            ForEach(Array(brackets.reversed().enumerated()), id: \.offset) { index, bracket in
                Label {
                    Text(bracket.label)
                } icon: {
                    RoundedRectangle(cornerRadius: Tokens.Space.xxs, style: .continuous)
                        .strokeBorder(bracketColor(bracket.tier), lineWidth: Tokens.Space.xxs)
                        .frame(width: swatchWidths[index], height: Tokens.Space.m)
                }
            }
        }
        .artTextStyle(Tokens.Typography.provenance)
        .foregroundStyle(Tokens.Color.textSecondary)
        .opacity(phase >= .settle ? 1 : 0)
        .animation(reduceMotion ? ArtMotion.crossfade : ArtMotion.fast, value: phase >= .settle)
    }

    private func bracketColor(_ tier: BidTier) -> Color {
        Tokens.Color.accentGilt.opacity(tier == .expertEye ? 1 : Tokens.Motion.Reveal.dimOpacity)
    }
}
