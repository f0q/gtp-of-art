import ArtCore
import ArtDesign
import SwiftUI

extension Swatch {
    /// `#RRGGBB` for `Color(datasetHex:)`.
    var hex: String {
        let digits = Array("0123456789ABCDEF")
        func byte(_ v: Int) -> String {
            let c = min(max(v, 0), 255)
            return String([digits[c / 16], digits[c % 16]])
        }
        return "#" + byte(red) + byte(green) + byte(blue)
    }

    var color: Color { Color(datasetHex: hex) ?? Tokens.Color.bgElevated }
}

/// A "pigment bar": a gradient painted from the player's liked works' swatches, a gilt marker at
/// the axis value and word endpoints. `fill` (0…1) draws the pigment in during the reveal.
struct PigmentBar: View {
    let axis: TasteAxis
    let value: Double
    let stops: [Swatch]
    var fill: Double = 1
    /// One caption line above the bar (share cards); otherwise title above, endpoints below.
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 0 : Tokens.Space.xs) {
            if compact {
                HStack(alignment: .firstTextBaseline) {
                    Text(axis.title).foregroundStyle(Tokens.Color.textPrimary)
                    Spacer(minLength: Tokens.Space.s)
                    Text("\(axis.endpoints.low) – \(axis.endpoints.high)").foregroundStyle(Tokens.Color.textSecondary)
                }
                .artTextStyle(Tokens.Typography.provenance)
                track
            } else {
                Text(axis.title)
                    .artTextStyle(Tokens.Typography.label)
                    .foregroundStyle(Tokens.Color.textPrimary)
                track
                HStack(alignment: .firstTextBaseline) {
                    Text(axis.endpoints.low)
                    Spacer(minLength: Tokens.Space.s)
                    Text(axis.endpoints.high)
                }
                .artTextStyle(Tokens.Typography.provenance)
                .foregroundStyle(Tokens.Color.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(axis.spoken(value))
        .accessibilityIdentifier("taste.bar.\(axis.title.lowercased())")
    }

    private var gradient: LinearGradient {
        let colors = stops.isEmpty ? [Tokens.Color.bgElevated, Tokens.Color.textSecondary] : stops.map(\.color)
        return LinearGradient(colors: colors.count == 1 ? colors + colors : colors, startPoint: .leading, endPoint: .trailing)
    }

    private var track: some View {
        Capsule()
            .fill(Tokens.Color.bgElevated)
            .overlay(alignment: .leading) {
                Capsule().fill(gradient)
                    .mask(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule().frame(width: geo.size.width * fill)
                        }
                    }
            }
            .overlay {
                Capsule().strokeBorder(Tokens.Color.lineHairline, lineWidth: Tokens.Size.hairline)
            }
            .frame(height: Tokens.Space.m)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    marker
                        .position(
                            x: geo.size.width * TasteAxis.position(value),
                            y: geo.size.height / 2)
                        .opacity(fill >= 1 ? 1 : 0)
                }
            }
            .padding(.vertical, Tokens.Space.xs)
    }

    private var marker: some View {
        Capsule()
            .fill(Tokens.Color.accentGilt)
            .overlay { Capsule().strokeBorder(Tokens.Color.bgCanvas, lineWidth: Tokens.Space.xxs) }
            .frame(width: Tokens.Space.m, height: Tokens.Space.xl)
    }
}

/// "Edition N / 100": a 10×10 grid with N gilt dots.
struct EditionGrid: View {
    let lit: Int

    var body: some View {
        Grid(horizontalSpacing: Tokens.Space.xs, verticalSpacing: Tokens.Space.xs) {
            ForEach(0..<10, id: \.self) { row in
                GridRow {
                    ForEach(0..<10, id: \.self) { col in
                        let n = row * 10 + col
                        Circle()
                            .fill(n < lit ? Tokens.Color.accentGilt : Tokens.Color.lineHairline)
                            .frame(width: Tokens.Space.s, height: Tokens.Space.s)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Edition \(lit) of 100")
    }
}
