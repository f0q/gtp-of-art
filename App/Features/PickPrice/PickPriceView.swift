import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Pick the price: fixed artwork zone on top; four ascending 56pt options in the thumb zone; on
/// reveal the options collapse to the sale price (+ the player's pick) under the rolling price.
struct PickPriceView: View {
    @Bindable var model: PickPriceModel
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
        VStack(spacing: 0) {
            SessionTopBar(progress: model.progress, score: model.session.totalPoints, onQuit: actions.close)
                .padding(.horizontal, Tokens.Space.l)
                .padding(.top, Tokens.Space.s)
            SessionStage {
                if let artwork = model.artwork { ArtworkZone(artwork: artwork, onTap: tapArtwork) }
            } answers: {
                answers
            }
        }
        .safeAreaInset(edge: .bottom) {
            SessionBottomBar {
                if model.isRevealing && model.reveal.phase >= .next {
                    SessionActionButton(
                        title: model.session.isFinished ? "See results" : "Next lot", identifier: "session.next",
                        action: advance)
                    .transition(.opacity)
                }
            }
        }
        .revealHaptics(model.reveal)
        .task(id: model.session.index) { await autoAnswerIfRequested() }
    }

    @ViewBuilder
    private var answers: some View {
        if let round = model.round, let price = model.price, let artwork = model.artwork {
            PickAnswers(
                round: round, price: price, artwork: artwork, chosenIndex: model.chosenIndex,
                outcome: model.outcome, isRevealing: model.isRevealing, phase: model.reveal.phase, onChoose: choose)
        }
    }

    private func choose(_ index: Int) {
        guard let outcome = model.choose(index), let price = model.price else { return }
        app.prefetch(model.upcomingArtworks)
        let verdict = outcome.isCorrect == true ? "Correct." : "Not quite."
        model.reveal.start(
            isHit: outcome.isCorrect == true, reduceMotion: reduceMotion,
            announcement: "\(verdict) \(PriceCopy.provenance(price, showVenue: true)).")
    }

    private func tapArtwork() {
        guard model.isRevealing else { return }
        if model.reveal.phase < .next { model.reveal.skipToEnd() } else { advance() }
    }

    private func advance() {
        withArtAnimation(ArtMotion.entrance, reduceMotion: reduceMotion) { model.advance() }
    }

    private func autoAnswerIfRequested() async {
        guard app.debug.autoAnswer, model.session.index == 0, !model.isRevealing else { return }
        try? await Task.sleep(for: .seconds(1.5))
        choose(model.round?.correctIndex ?? 0)
    }
}

/// Pick-the-price answer zone (also used by the daily): question + four options, and the reveal
/// (rolling price, result, provenance, the sale price and the player's pick) in the same space.
struct PickAnswers: View {
    let round: PickPriceRound
    let price: PriceRecord
    let artwork: Artwork
    let chosenIndex: Int?
    let outcome: RoundOutcome?
    let isRevealing: Bool
    let phase: RevealPhase
    var allowsStreakBonus = true
    let onChoose: (Int) -> Void

    var body: some View {
        let chosen = chosenIndex ?? round.correctIndex
        PhaseLayers(isRevealing: isRevealing) {
            VStack(spacing: Tokens.Space.m) {
                Text(PriceCopy.question(price))
                    .artTextStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("pick.question")
                ForEach(Array(round.options.enumerated()), id: \.offset) { index, usd in
                    PriceOptionButton(label: PriceCopy.amount(usd), index: index, state: .idle) { onChoose(index) }
                }
            }
        } reveal: {
            VStack(spacing: Tokens.Space.s) {
                RevealPrice(guess: Double(round.options[chosen]), actual: Double(price.usdNominal),
                            finalText: PriceFormatter.format(price, basis: .nominal), phase: phase)
                    .artTextStyle(Tokens.Typography.priceHero)
                    .foregroundStyle(Tokens.Color.accentGilt)
                    .revealSettle(phase: phase)
                    .accessibilityIdentifier("reveal.price")
                ResultBadge(isHit: outcome?.isCorrect == true, hitText: bonusText, missText: "Not this time")
                    .revealProvenance(phase: phase)
                ProvenanceLine(artwork: artwork, record: price)
                    .revealProvenance(phase: phase)
                VStack(spacing: Tokens.Space.m) {
                    PriceOptionButton(label: PriceCopy.amount(round.options[round.correctIndex]),
                                      index: round.correctIndex, state: phase >= .settle ? .correct : .idle,
                                      isChosen: chosen == round.correctIndex) {}
                    if chosen != round.correctIndex {
                        PriceOptionButton(label: PriceCopy.amount(round.options[chosen]), index: chosen,
                                          state: phase >= .settle ? .chosenWrong : .idle, isChosen: true) {}
                    } else {
                        // Keeps the reveal layer the same height whether the pick was right or wrong.
                        Color.clear.frame(height: Tokens.Size.answerButton)
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }

    private var bonusText: String {
        guard let points = outcome?.points, allowsStreakBonus else { return "Correct" }
        return points > Scorer.basePoints ? "Correct · streak bonus +\(points - Scorer.basePoints)" : "Correct"
    }
}

/// One full-width 56pt answer option (`.artButtonStyle(.option)` + `.artOptionState`): the sale
/// price fills (hit + "Sale price"); the player's wrong pick keeps the gilt outline + "Your pick".
struct PriceOptionButton: View {
    enum State { case idle, correct, chosenWrong }

    let label: String
    let index: Int
    let state: State
    var isChosen = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .monospacedDigit()
                Spacer(minLength: Tokens.Space.s)
                switch state {
                case .idle: EmptyView()
                case .correct:
                    Label("Sale price", systemImage: "checkmark.circle.fill")
                        .artTextStyle(Tokens.Typography.provenance)
                case .chosenWrong:
                    Label("Your pick", systemImage: "xmark.circle")
                        .artTextStyle(Tokens.Typography.provenance)
                        .foregroundStyle(Tokens.Color.feedbackMiss)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .artButtonStyle(.option)
        .artOptionState(state == .correct ? .correct : .normal)
        .overlay {
            if isChosen && state != .correct {
                RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous)
                    .strokeBorder(Tokens.Color.accentGilt, lineWidth: Tokens.Space.xxs)
            }
        }
        .accessibilityIdentifier("pick.option.\(index)")
        .accessibilityLabel(state == .correct ? "\(label), sale price" : label)
    }
}

/// Icon + word + colour for a round result (never colour alone).
struct ResultBadge: View {
    let isHit: Bool
    var hitText = "Correct"
    var missText = "Missed"

    var body: some View {
        Label(isHit ? hitText : missText, systemImage: isHit ? "checkmark.seal.fill" : "xmark.seal")
            .artTextStyle(Tokens.Typography.label)
            .foregroundStyle(isHit ? Tokens.Color.feedbackHit : Tokens.Color.feedbackMiss)
            .accessibilityIdentifier("reveal.result")
    }
}
