import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Daily result: ◆/◇/▢ tiles, total /500, streak (gilt frame), countdown to the next local
/// midnight, image share card + text grid.
struct DailyResultView: View {
    let model: DailyModel
    let actions: SessionActions

    @Environment(\.app) private var app
    @Environment(\.colorScheme) private var colorScheme
    @State private var shareImage: ShareCardImage?
    @State private var sharePreview: Image?

    var body: some View {
        // Centred between the top edge and the action bar when it fits; scrolls when it does not.
        GeometryReader { geo in
        ScrollView {
            VStack(spacing: Tokens.Space.xl) {
                Spacer(minLength: 0)
                Text("Daily Challenge · Day \(model.dayNumber)")
                    .artTextStyle(Tokens.Typography.provenance)
                    .foregroundStyle(Tokens.Color.textSecondary)
                if model.isPractice {
                    SoonLabel(text: "Practice · today's score is kept")
                }
                DailyResultTiles(model: model)
                Text("\(model.total)/\(DailyModel.maxTotal)")
                    .artTextStyle(Tokens.Typography.displayXL)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Color.accentGilt)
                    .accessibilityIdentifier("daily.total")
                Label {
                    Text(model.streak == 1 ? "1 day streak" : "\(model.streak) day streak")
                } icon: {
                    Image(systemName: "photo.artframe").foregroundStyle(Tokens.Color.accentGilt)
                }
                .artTextStyle(Tokens.Typography.label)
                .foregroundStyle(Tokens.Color.textPrimary)
                .accessibilityIdentifier("daily.streak")
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("Next challenge in \(countdown(from: app.freezesClock ? app.now() : context.date))")
                        .artTextStyle(Tokens.Typography.label)
                        .monospacedDigit()
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
                .accessibilityIdentifier("daily.countdown")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.xl)
            .frame(maxWidth: .infinity, minHeight: geo.size.height)
        }
        .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) { buttons }
        .background(Tokens.Color.bgCanvas.ignoresSafeArea())
        .task(id: colorScheme) { await renderShareCard() }
    }

    /// Time to the next local midnight (`SystemDayProvider.nextDayStart`).
    private func countdown(from now: Date) -> String {
        let next = SystemDayProvider.nextDayStart(after: now, in: .current)
        let seconds = max(0, Int(next.timeIntervalSince(now)))
        return Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
    }

    private var buttons: some View {
        // Equal slots, one-line titles; icon-only or stacked when the titles cannot fit.
        ActionRow {
            Button(action: actions.close) {
                Label("Home", systemImage: "house").actionRowItem()
            }
            .artButtonStyle(.secondary)
            .accessibilityIdentifier("summary.home")
            ShareLink(item: model.shareText) {
                Label("Grid", systemImage: "text.alignleft").actionRowItem()
            }
            .artButtonStyle(.secondary)
            .accessibilityLabel("Share grid")
            .accessibilityIdentifier("daily.shareText")
            if let shareImage, let sharePreview {
                ShareLink(item: shareImage, preview: SharePreview(model.shareText, image: sharePreview)) {
                    Label("Card", systemImage: "square.and.arrow.up").actionRowItem()
                }
                .artButtonStyle(.secondary)
                .accessibilityLabel("Share card")
                .accessibilityIdentifier("summary.share")
            }
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.vertical, Tokens.Space.s)
        .background(Tokens.Color.bgCanvas.ignoresSafeArea(edges: .bottom))
    }

    private func renderShareCard() async {
        let summary = model.summary()
        var image: CGImage?
        if let featured = summary.featured,
            let request = ArtworkImageRequest.make(featured, .large, locator: app.dataset.images)
        {
            image = try? await app.imageLoader.image(for: request)
        }
        let card = ShareCardFactory.card(summary, image: image, locator: app.dataset)
        guard let cg = ShareCardRenderer.cgImage(card, colorScheme: colorScheme),
            let png = ShareCardRenderer.encodePNG(cg)
        else { return }
        shareImage = ShareCardImage(png: png)
        sharePreview = Image(decorative: cg, scale: Tokens.Size.shareCardScale)
    }
}

/// The five result tiles: mark + round kind + points.
struct DailyResultTiles: View {
    let model: DailyModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Tokens.Space.s)) : AnyLayout(HStackLayout(spacing: Tokens.Space.s))
        layout {
            ForEach(Array(zip(model.session.rounds, model.session.outcomes).enumerated()), id: \.offset) { i, pair in
                let mark = model.marks[i]
                VStack(spacing: Tokens.Space.xs) {
                    Image(systemName: mark.symbol)
                        .font(.title.weight(.medium))
                        .foregroundStyle(mark == .miss ? Tokens.Color.textSecondary : Tokens.Color.accentGilt)
                    Text(DailyModel.kindTitle(pair.0))
                        .artTextStyle(Tokens.Typography.provenance)
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        // Two lines reserved in a row so every tile's mark, title and score align.
                        .lineLimit(2, reservesSpace: !typeSize.isAccessibilitySize)
                    Spacer(minLength: 0)
                    Text("\(pair.1.points)")
                        .artTextStyle(Tokens.Typography.label)
                        .monospacedDigit()
                        .foregroundStyle(Tokens.Color.textPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, Tokens.Space.s)
                .background(Tokens.Color.bgSurface,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Round \(i + 1), \(DailyModel.kindTitle(pair.0)), \(mark.label), \(pair.1.points) points")
            }
        }
        // Equal-height tiles: each takes the tallest tile's height.
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("daily.tiles")
    }
}
