import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Which is pricier: two frames stacked vertically with a "vs" medallion; tap the pricier one.
/// Both prices roll; the winner lifts with a gilt border, the loser dims; the chain continues.
struct PricierView: View {
    @Bindable var model: PricierModel
    let actions: SessionActions

    @Environment(\.app) private var app
    @Environment(\.artReduceMotion) private var reduceMotion

    var body: some View {
        if model.isOver {
            SessionSummaryView(summary: model.summary(), actions: actions)
        } else {
            round
        }
    }

    private var round: some View {
        VStack(spacing: Tokens.Space.s) {
            SessionTopBar(progress: .streak(model.streak), score: model.session.totalPoints, onQuit: quit)
                .padding(.horizontal, Tokens.Space.l)
                .padding(.top, Tokens.Space.s)
            if let round = model.round, let top = model.top, let bottom = model.bottom {
                PricierPair(
                    round: round, top: top, bottom: bottom, outcome: model.outcome, isRevealing: model.isRevealing,
                    phase: model.reveal.phase, onTap: tap)
            }
        }
        .safeAreaInset(edge: .bottom) {
            SessionBottomBar {
                if model.isRevealing && model.reveal.phase >= .next {
                    SessionActionButton(
                        title: model.session.isFinished ? "See results" : "Next pair", identifier: "session.next",
                        action: advance)
                    .transition(.opacity)
                } else if model.bestStreak > 0 {
                    Text("Personal best \(model.bestStreak)")
                        .artTextStyle(Tokens.Typography.provenance)
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
            }
        }
        .revealHaptics(model.reveal)
        .task(id: model.session.index) { await autoAnswerIfRequested() }
    }

    private func tap(_ side: PricierSide) {
        if model.isRevealing {
            if model.reveal.phase < .next { model.reveal.skipToEnd() } else { advance() }
            return
        }
        guard let outcome = model.choose(side) else { return }
        app.prefetch(model.upcomingArtworks)
        let winner = model.round.flatMap { model.artwork($0.pricierSide) }
        model.reveal.start(
            isHit: outcome.isCorrect == true, reduceMotion: reduceMotion,
            announcement: "\(outcome.isCorrect == true ? "Correct" : "Not quite"). \(winner?.title ?? "") sold for more.")
    }

    private func advance() {
        withArtAnimation(ArtMotion.chain, reduceMotion: reduceMotion) { model.advance() }
    }

    private func quit() {
        model.quit()
        actions.close()
    }

    private func autoAnswerIfRequested() async {
        guard app.debug.autoAnswer, model.session.index == 0, !model.isRevealing, let round = model.round else { return }
        try? await Task.sleep(for: .seconds(1.5))
        tap(round.pricierSide)
    }
}

/// The pair (also used by the daily): prompt or result badge, two stacked frames sized with
/// `Tokens.Layout.pricierFrameFraction`, and the "vs" medallion between them.
struct PricierPair: View {
    let round: HigherLowerRound
    let top: Artwork
    let bottom: Artwork
    let outcome: RoundOutcome?
    let isRevealing: Bool
    let phase: RevealPhase
    let onTap: (PricierSide) -> Void

    @Namespace private var frames

    var body: some View {
        VStack(spacing: Tokens.Space.s) {
            Group {
                if isRevealing {
                    ResultBadge(isHit: outcome?.isCorrect == true, hitText: "Correct · the chain goes on",
                                missText: "Not this time · the run ends")
                } else {
                    Text("Tap the one that sold for more, in today's dollars")
                        .artTextStyle(Tokens.Typography.label)
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .accessibilityIdentifier("pricier.prompt")
                }
            }
            .multilineTextAlignment(.center)
            GeometryReader { geo in
                let slotHeight = geo.size.height * Tokens.Layout.pricierFrameFraction
                VStack(spacing: 0) {
                    slot(top, .top).frame(height: slotHeight)
                    Spacer(minLength: 0)
                    slot(bottom, .bottom).frame(height: slotHeight)
                }
                .overlay { VersusMedallion() }
            }
        }
        .padding(.horizontal, Tokens.Space.l)
    }

    private func slot(_ artwork: Artwork, _ side: PricierSide) -> some View {
        PricierSlot(
            artwork: artwork, side: side, isWinner: round.pricierSide == side, phase: phase, isRevealing: isRevealing
        ) { onTap(side) }
        .matchedGeometryEffect(id: artwork.id, in: frames)
        .transition(.opacity)
    }
}

/// One frame of the pair: artwork (the losing image dims after the reveal), Fraunces title and
/// artist, then one adjusted price headline and a nominal "sold" line (space reserved, no jump).
struct PricierSlot: View {
    let artwork: Artwork
    let side: PricierSide
    let isWinner: Bool
    let phase: RevealPhase
    let isRevealing: Bool
    let action: () -> Void

    @Environment(\.artReduceMotion) private var reduceMotion

    private var settled: Bool { isRevealing && phase >= .settle }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Tokens.Space.xs) {
                ArtworkImage(artwork: artwork, decorative: true)
                    .overlay {
                        if settled && isWinner {
                            Rectangle().strokeBorder(Tokens.Color.accentGilt, lineWidth: Tokens.Space.xxs)
                        }
                    }
                    .scaleEffect(settled && isWinner && !reduceMotion ? Tokens.Layout.winnerLift : 1)
                    .opacity(settled && !isWinner ? Tokens.Layout.disabledTileOpacity : 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(1)
                ArtworkCaption(artwork: artwork)
                    .lineLimit(2)
                if let price = artwork.gamePrice {
                    VStack(spacing: Tokens.Space.xxs) {
                        RevealPrice(guess: nil, actual: Double(price.usdAdjusted),
                                    finalText: PriceFormatter.format(price, basis: .adjusted) + " today", phase: phase)
                            .artTextStyle(Tokens.Typography.label)
                            .foregroundStyle(Tokens.Color.accentGilt)
                        Text(PriceCopy.soldThen(price))
                            .artTextStyle(Tokens.Typography.provenance)
                            .foregroundStyle(Tokens.Color.textSecondary)
                            .revealProvenance(phase: phase)
                    }
                    .opacity(isRevealing ? 1 : 0)
                    .accessibilityHidden(!isRevealing)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(ArtMotion.resolved(ArtMotion.settle, reduceMotion: reduceMotion), value: phase)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(isRevealing ? "Shows the next pair" : "Choose as the pricier work")
        .accessibilityIdentifier(side == .top ? "pricier.top" : "pricier.bottom")
    }

    private var accessibilityText: String {
        let position = side == .top ? "Top" : "Bottom"
        var text = "\(position): \(artwork.title), \(artwork.artist.displayName). \(artwork.image.altText)"
        if isRevealing, let price = artwork.gamePrice {
            text += " \(PriceCopy.adjusted(price))."
        }
        return text
    }
}

/// The "vs" medallion between the frames (solid, never glass over artwork).
struct VersusMedallion: View {
    var body: some View {
        Text("vs")
            .artTextStyle(Tokens.Typography.titleArt)
            .foregroundStyle(Tokens.Color.textSecondary)
            .frame(width: Tokens.Size.minTarget, height: Tokens.Size.minTarget)
            .background(Tokens.Color.bgSurface, in: Circle())
            .overlay(Circle().strokeBorder(Tokens.Color.lineHairline, lineWidth: Tokens.Size.hairline))
            .accessibilityHidden(true)
    }
}
