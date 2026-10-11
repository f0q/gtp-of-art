import ArtCore
import ArtDesign
import SwiftUI

/// Archetype name (Fraunces 40pt) and its one-line character.
struct ArchetypeHeader: View {
    let reading: TasteReading

    var body: some View {
        VStack(spacing: Tokens.Space.s) {
            Text(reading.archetype.name)
                .artTextStyle(Tokens.Typography.displayXL)
                .foregroundStyle(Tokens.Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("taste.archetype")
            Text(reading.archetype.line)
                .artTextStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textSecondary)
            if let session = reading.session, let edge = session.edge {
                Label {
                    Text("\(edge.title). \(edge.line(likes: session.liked.count, swipes: session.swipes))")
                } icon: {
                    Image(systemName: edge == .purist ? "scope" : "square.grid.3x3.fill")
                }
                .artTextStyle(Tokens.Typography.label)
                .foregroundStyle(Tokens.Color.textPrimary)
                .accessibilityIdentifier("taste.edge")
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The four pigment bars; `fills[i]` draws bar i in (0…1).
struct PigmentBars: View {
    let reading: TasteReading
    var fills: [Double] = [1, 1, 1, 1]

    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            ForEach(Array(TasteAxis.allCases.enumerated()), id: \.offset) { i, axis in
                PigmentBar(
                    axis: axis, value: axis.value(reading.report.axes), stops: axis.stops(from: reading.swatches),
                    fill: fills.indices.contains(i) ? fills[i] : 1)
            }
        }
    }
}

/// Rarity band/percentile line plus "Edition N / 100" with its dot grid. All copy "estimated".
struct RarityBlock: View {
    let reading: TasteReading

    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            Text(reading.rarityLine)
                .artTextStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("taste.rarity")
            if let edition = reading.edition {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Tokens.Space.l) { grid(edition); editionText(edition, alignment: .leading) }
                    VStack(spacing: Tokens.Space.m) { grid(edition); editionText(edition, alignment: .center) }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func grid(_ edition: Int) -> some View {
        EditionGrid(lit: edition).accessibilityHidden(true)
    }

    private func editionText(_ edition: Int, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Tokens.Space.xs) {
            Text(TasteCopy.edition(edition))
                .artTextStyle(Tokens.Typography.displayL)
                .monospacedDigit()
                .foregroundStyle(Tokens.Color.accentGilt)
            Text(TasteCopy.share(edition))
                .artTextStyle(Tokens.Typography.provenance)
                .foregroundStyle(Tokens.Color.textSecondary)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("taste.edition")
    }
}

/// "Your wall would have cost ≈ $1.3B" with an ⓘ explaining what the figure is.
struct WallCostLine: View {
    let reading: TasteReading
    @State private var showingInfo = false

    var body: some View {
        if let text = reading.wallCostText, let session = reading.session {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
                Text("Your wall would have cost \(text) approx.")
                    .artTextStyle(Tokens.Typography.label)
                    .foregroundStyle(Tokens.Color.accentGilt)
                    .accessibilityIdentifier("taste.wallCost")
                Button { showingInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .frame(minWidth: Tokens.Size.minTarget, minHeight: Tokens.Size.minTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About this figure")
            }
            .multilineTextAlignment(.center)
            .sheet(isPresented: $showingInfo) {
                WallCostInfo(priced: session.pricedLiked.count, liked: session.liked.count)
            }
        }
    }
}

/// ⓘ for the wall cost.
struct WallCostInfo: View {
    let priced: Int
    let liked: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Text("The sum of the last public sale price of each work you kept that has one (\(priced) of \(liked)), adjusted for inflation.")
                Text("Sale prices are approximate public figures: auction results usually include the buyer's premium; private sales are as reported. Inflation adjustment is an estimate.")
                    .foregroundStyle(Tokens.Color.textSecondary)
                Text("For entertainment and education only. Not an appraisal or valuation.")
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
            .artTextStyle(Tokens.Typography.body)
            .scrollContentBackground(.hidden)
            .background(Tokens.Color.bgCanvas)
            .navigationTitle("Wall value, approx.")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
