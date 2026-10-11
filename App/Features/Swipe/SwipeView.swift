import ArtCore
import ArtData
import ArtDesign
import SwiftUI

/// Swipe mode: a 3-card stack with ✕/♥ buttons and undo, 20 progress dots, then the taste reveal.
struct SwipeView: View {
    @Bindable var model: SwipeModel
    let actions: SessionActions

    @Environment(\.app) private var app
    @State private var details: Artwork?
    @State private var screenHeight: CGFloat = 0

    var body: some View {
        if let reading = model.reading {
            TasteRevealView(reading: reading, actions: actions)
        } else {
            deckScreen
        }
    }

    private var deckScreen: some View {
        VStack(spacing: Tokens.Space.l) {
            SwipeTopBar(model: model, onQuit: quit)
                .padding(.horizontal, Tokens.Space.l)
                .padding(.top, Tokens.Space.s)
            CardStack(
                items: model.deck, controller: model.stack,
                onSwipe: { item, direction in
                    guard item.id == model.topArtwork?.id else { return }
                    model.swipe(liked: direction == .like)
                },
                onUndo: { model.undo() },
                onDetails: { details = $0.artwork }
            ) { item in
                SwipeCard(artwork: item.artwork, maxArtworkHeight: screenHeight * Tokens.Layout.artworkHeightFraction)
            }
            .accessibilityIdentifier("swipe.stack")
            CardStackButtons(controller: model.stack)
                .padding(.bottom, Tokens.Space.s)
        }
        .background(Tokens.Color.bgCanvas.ignoresSafeArea())
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { screenHeight = $0 }
        .sheet(item: $details) { SwipeDetailSheet(artwork: $0) }
        .task(id: model.swipedCount) { app.prefetch(model.upcomingArtworks) }
        .task { await autoSwipeIfRequested() }
    }

    private func quit() {
        model.close()
        actions.close()
    }

    /// DEBUG `-autoAnswer`: swipes every card (a fixed like/pass pattern) to reach the reveal.
    private func autoSwipeIfRequested() async {
        guard app.debug.autoAnswer, model.swipedCount == 0 else { return }
        try? await Task.sleep(for: .seconds(1.5))
        var n = 0
        while !model.isFinished {
            model.swipe(liked: SwipeDebug.likes(n))
            n += 1
        }
    }
}

/// ✕ (with confirmation), 20 dots and the "12 more to reveal your taste" line. No score: swipes
/// are not right or wrong.
struct SwipeTopBar: View {
    let model: SwipeModel
    let onQuit: () -> Void
    @State private var confirmingQuit = false

    var body: some View {
        VStack(spacing: Tokens.Space.s) {
            HStack(spacing: Tokens.Space.m) {
                Button { confirmingQuit = true } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Tokens.Color.textPrimary)
                        .frame(width: Tokens.Size.minTarget, height: Tokens.Size.minTarget)
                        .artGlass(Circle(), interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quit session")
                .accessibilityIdentifier("session.close")
                Text(model.progressCopy ?? "Keep or pass. No prices yet.")
                    .artTextStyle(Tokens.Typography.label)
                    .foregroundStyle(model.progressCopy == nil ? Tokens.Color.textSecondary : Tokens.Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("swipe.copy")
            }
            SwipeProgressDots(current: model.currentCard, total: model.total)
        }
        .confirmationDialog("Leave this session?", isPresented: $confirmingQuit, titleVisibility: .visible) {
            Button("Leave", role: .destructive, action: onQuit)
            Button("Keep swiping", role: .cancel) {}
        } message: {
            Text("Cards you have swiped are kept in your taste profile.")
        }
    }
}

/// Fixed like/pass pattern for DEBUG auto-swipes and screenshot seeding (13 likes in 20).
nonisolated enum SwipeDebug {
    static func likes(_ n: Int) -> Bool { n % 3 != 2 }
}
