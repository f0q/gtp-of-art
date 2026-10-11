import ArtCore
import ArtData
import ArtDesign
import SwiftUI

/// Reveal stages in order (plan C5).
enum TasteRevealStage: Int, Comparable {
    case wall, archetype, bars, rarity

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// The taste reveal after card 20: (1) the salon wall, (2) archetype, (3) pigment bars,
/// (4) rarity + edition and the wall's cost. Tap "Skip" to jump to the end; Reduce Motion
/// replaces every movement with short fades.
struct TasteRevealView: View {
    let reading: TasteReading
    let actions: SessionActions

    @Environment(\.app) private var app
    @Environment(\.artReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var stage: TasteRevealStage
    @State private var hung: Int
    @State private var fills: [Double]
    @State private var shares: [TasteShareFormat: (image: ShareCardImage, preview: Image)] = [:]

    init(reading: TasteReading, actions: SessionActions, startsComplete: Bool = false) {
        self.reading = reading
        self.actions = actions
        _stage = State(initialValue: startsComplete ? .rarity : .wall)
        _hung = State(initialValue: startsComplete ? (reading.session?.wall.count ?? 0) : 0)
        _fills = State(initialValue: Array(repeating: startsComplete ? 1 : 0, count: TasteAxis.allCases.count))
    }

    private var wall: [Artwork] { reading.session?.wall ?? [] }
    private var isComplete: Bool { stage == .rarity && hung == wall.count && fills.allSatisfy { $0 >= 1 } }

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.Space.xl) {
                Text("Your Salon Wall")
                    .artTextStyle(Tokens.Typography.provenance)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                if wall.isEmpty {
                    Text("Nothing made the wall this time.")
                        .artTextStyle(Tokens.Typography.body)
                        .foregroundStyle(Tokens.Color.textSecondary)
                } else {
                    SalonWall(works: wall, hung: hung)
                }
                if stage >= .archetype {
                    ArchetypeHeader(reading: reading).artTransition(.move(edge: .bottom).combined(with: .opacity))
                }
                if stage >= .bars {
                    PigmentBars(reading: reading, fills: fills).transition(.opacity)
                }
                if stage >= .rarity {
                    VStack(spacing: Tokens.Space.l) {
                        RarityBlock(reading: reading)
                        if let leaning = reading.leaning {
                            Text(leaning)
                                .artTextStyle(Tokens.Typography.body)
                                .foregroundStyle(Tokens.Color.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        WallCostLine(reading: reading)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.xl)
            .frame(maxWidth: .infinity)
        }
        .background(Tokens.Color.bgCanvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { buttons }
        .task { await run() }
        .task(id: colorScheme) { await renderShareCards() }
    }

    // MARK: Buttons

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: Tokens.Space.m) {
            if isComplete {
                SessionPrimaryButton(title: "Swipe 20 more", identifier: "taste.again", action: actions.playAgain)
            } else {
                Button(action: skip) { Text("Skip to my taste").frame(maxWidth: .infinity) }
                    .artButtonStyle(.secondary)
                    .accessibilityIdentifier("taste.skip")
            }
            let row = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: Tokens.Space.m)) : AnyLayout(HStackLayout(spacing: Tokens.Space.m))
            row {
                Button(action: actions.close) {
                    Label("Home", systemImage: "house").frame(maxWidth: .infinity)
                }
                .artButtonStyle(.secondary)
                .accessibilityIdentifier("taste.home")
                shareLink(.feed, title: "Share", symbol: "square.and.arrow.up", id: "taste.share")
                shareLink(.story, title: "Story", symbol: "rectangle.portrait", id: "taste.shareStory")
            }
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.vertical, Tokens.Space.s)
        .background(Tokens.Color.bgCanvas.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private func shareLink(_ format: TasteShareFormat, title: String, symbol: String, id: String) -> some View {
        if let share = shares[format] {
            ShareLink(item: share.image, preview: SharePreview(reading.archetype.name, image: share.preview)) {
                Label(title, systemImage: symbol).frame(maxWidth: .infinity)
            }
            .artButtonStyle(.secondary)
            .accessibilityIdentifier(id)
        }
    }

    // MARK: Choreography

    private func run() async {
        guard !isComplete else { return }
        if reduceMotion {
            withAnimation(.easeInOut(duration: Tokens.Motion.Duration.base)) { complete() }
            announce()
            return
        }
        for i in wall.indices {
            withAnimation(Tokens.Motion.Spring.chain) { hung = i + 1 }
            try? await Task.sleep(for: .seconds(Tokens.Motion.Stagger.tight))
        }
        await pause(Tokens.Motion.Duration.profile - Tokens.Motion.Stagger.tight * Double(wall.count))
        withAnimation(ArtMotion.entrance) { stage = .archetype }
        await pause(Tokens.Motion.Duration.settle)
        withAnimation(ArtMotion.fast) { stage = .bars }
        for i in fills.indices {
            withAnimation(Tokens.Motion.Easing.standard(duration: Tokens.Motion.Duration.base)) { fills[i] = 1 }
            await pause(Tokens.Motion.Stagger.loose)
        }
        await pause(Tokens.Motion.Duration.reveal)
        withAnimation(ArtMotion.entrance) { stage = .rarity }
        announce()
    }

    private func pause(_ seconds: Double) async {
        guard seconds > 0, !Task.isCancelled else { return }
        try? await Task.sleep(for: .seconds(seconds))
    }

    private func complete() {
        hung = wall.count
        stage = .rarity
        fills = fills.map { _ in 1 }
    }

    private func skip() {
        withArtAnimation(ArtMotion.fast, reduceMotion: reduceMotion) { complete() }
        announce()
    }

    private func announce() {
        let text = "Your taste: \(reading.archetype.name). \(reading.archetype.line) \(reading.rarityLine)"
        AccessibilityNotification.Announcement(text).post()
    }

    // MARK: Share cards

    private func renderShareCards() async {
        var images: [ArtworkID: CGImage] = [:]
        for work in wall {
            if let request = ArtworkImageRequest.make(work, .small, locator: app.dataset.images),
                let image = try? await app.imageLoader.image(for: request)
            {
                images[work.id] = image
            }
        }
        var rendered: [TasteShareFormat: (image: ShareCardImage, preview: Image)] = [:]
        for format in TasteShareFormat.allCases {
            let card = ShareCardFactory.taste(reading, images: images, dataset: app.dataset, format: format)
            guard let cg = ShareCardRenderer.cgImage(card, colorScheme: colorScheme, size: format.size),
                let png = ShareCardRenderer.encodePNG(cg)
            else { continue }
            rendered[format] = (ShareCardImage(png: png), Image(decorative: cg, scale: Tokens.Size.shareCardScale))
        }
        shares = rendered
    }
}
