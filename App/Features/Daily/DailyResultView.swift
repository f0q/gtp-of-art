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
        ScrollView {
            VStack(spacing: Tokens.Space.xl) {
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
            }
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.xl)
            .frame(maxWidth: .infinity)
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
        HStack(spacing: Tokens.Space.m) {
            Button(action: actions.close) {
                Label("Home", systemImage: "house").frame(maxWidth: .infinity)
            }
            .artButtonStyle(.secondary)
            .accessibilityIdentifier("summary.home")
            ShareLink(item: model.shareText) {
                Label("Share grid", systemImage: "text.alignleft").frame(maxWidth: .infinity)
            }
            .artButtonStyle(.secondary)
            .accessibilityIdentifier("daily.shareText")
            if let shareImage, let sharePreview {
                ShareLink(item: shareImage, preview: SharePreview(model.shareText, image: sharePreview)) {
                    Label("Card", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .artButtonStyle(.secondary)
                .accessibilityIdentifier("summary.share")
            }
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.bottom, Tokens.Space.s)
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
                        .lineLimit(2)
                    Text("\(pair.1.points)")
                        .artTextStyle(Tokens.Typography.label)
                        .monospacedDigit()
                        .foregroundStyle(Tokens.Color.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Space.s)
                .background(Tokens.Color.bgSurface,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Round \(i + 1), \(DailyModel.kindTitle(pair.0)), \(mark.label), \(pair.1.points) points")
            }
        }
        .accessibilityIdentifier("daily.tiles")
    }
}
