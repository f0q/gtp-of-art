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
    @State private var announced = false

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
                if typeSize.isAccessibilitySize {
                    // At accessibility sizes the pinned bar keeps only the primary action; Home and
                    // Share scroll with the content so the reading keeps most of the screen.
                    secondaryButtons
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
            if !typeSize.isAccessibilitySize { secondaryButtons }
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.vertical, Tokens.Space.s)
        .background(Tokens.Color.bgCanvas.ignoresSafeArea(edges: .bottom))
    }

    /// Home, Share and Story: one row, or a column at accessibility sizes.
    private var secondaryButtons: some View {
        let row = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Tokens.Space.m)) : AnyLayout(HStackLayout(spacing: Tokens.Space.m))
        return row {
            Button(action: actions.close) {
                Label("Home", systemImage: "house").frame(maxWidth: .infinity)
            }
            .artButtonStyle(.secondary)
            .accessibilityIdentifier("taste.home")
            shareLink(.feed, title: "Share", symbol: "square.and.arrow.up", id: "taste.share")
            shareLink(.story, title: "Story", symbol: "rectangle.portrait", id: "taste.shareStory")
        }
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
            // No salon-wall fly-in: the works are hung without animation, the rest crossfades in.
            hangWithoutMotion()
            withAnimation(ArtMotion.crossfade) { complete() }
            announce()
            return
        }
        // Each step stops once "Skip" has completed the reveal (it must not un-hang works).
        for i in wall.indices {
            guard !isComplete else { return }
            withAnimation(Tokens.Motion.Spring.chain) { hung = i + 1 }
            try? await Task.sleep(for: .seconds(Tokens.Motion.Stagger.tight))
        }
        await pause(Tokens.Motion.Duration.profile - Tokens.Motion.Stagger.tight * Double(wall.count))
        guard !isComplete else { return }
        withAnimation(ArtMotion.entrance) { stage = .archetype }
        await pause(Tokens.Motion.Duration.settle)
        guard !isComplete else { return }
        withAnimation(ArtMotion.fast) { stage = .bars }
        for i in fills.indices {
            guard !isComplete else { return }
            withAnimation(Tokens.Motion.Easing.standard(duration: Tokens.Motion.Duration.base)) { fills[i] = 1 }
            await pause(Tokens.Motion.Stagger.loose)
        }
        await pause(Tokens.Motion.Duration.reveal)
        guard !isComplete else { return }
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
        if reduceMotion { hangWithoutMotion() }
        withArtAnimation(ArtMotion.fast, reduceMotion: reduceMotion) { complete() }
        announce()
    }

    /// Puts every liked work on the wall in one frame (Reduce Motion: no matched-geometry flight).
    private func hangWithoutMotion() {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { hung = wall.count }
    }

    /// Posts the taste summary once, whether the choreography finished or the player skipped.
    private func announce() {
        guard !announced else { return }
        announced = true
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
