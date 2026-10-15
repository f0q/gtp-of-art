import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Daily challenge: intro card per round ("Round 3 · Bid"), the round in its own mode's layout,
/// then the result screen.
struct DailyView: View {
    @Bindable var model: DailyModel
    let actions: SessionActions

    @Environment(\.app) private var app
    @Environment(\.artReduceMotion) private var reduceMotion
    @State private var showsClue = false

    var body: some View {
        if model.isOver {
            DailyResultView(model: model, actions: actions)
        } else {
            VStack(spacing: 0) {
                SessionTopBar(progress: model.progress, score: model.total, onQuit: actions.close)
                    .padding(.horizontal, Tokens.Space.l)
                    .padding(.top, Tokens.Space.s)
                if model.stage == .intro {
                    DailyIntroCard(model: model)
                        .transition(.opacity)
                } else {
                    roundView
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .revealHaptics(model.reveal)
            .task { await autoPlayIfRequested() }
        }
    }

    @ViewBuilder
    private var roundView: some View {
        let phase = model.reveal.phase
        switch model.round {
        case .pickPrice(let r)?:
            if let artwork = model.dataset.artwork(r.artwork), let price = artwork.price(id: r.priceID) {
                SessionStage {
                    ArtworkZone(artwork: artwork, onTap: tapArtwork)
                } answers: {
                    PickAnswers(round: r, price: price, artwork: artwork, chosenIndex: model.chosenIndex,
                                outcome: model.outcome, isRevealing: model.isRevealing, phase: phase,
                                allowsStreakBonus: false) { submit(.pickPrice(index: $0)) }
                }
            }
        case .category(let r)?:
            if let artwork = model.dataset.artwork(r.artwork) {
                SessionStage {
                    CategoryArtZone(artwork: artwork, showsClue: showsClue, onTap: tapArtwork)
                } answers: {
                    CategoryAnswers(
                        round: r, artwork: artwork, labels: r.options.map { CategoryCopy.label($0, dataset: model.dataset) },
                        truth: model.dataset.category(r.options[r.correctIndex]), chosenIndex: model.chosenIndex,
                        outcome: model.outcome, isRevealing: model.isRevealing, phase: phase,
                        showsClue: $showsClue) { submit(.category(index: $0)) }
                }
            }
        case .bid(let r)?:
            if let artwork = model.dataset.artwork(r.artwork), let price = artwork.price(id: r.priceID) {
                SessionStage {
                    ArtworkZone(artwork: artwork, onTap: tapArtwork)
                } answers: {
                    BidAnswers(round: r, price: price, artwork: artwork, position: $model.bidPosition,
                               bounds: model.bidBounds, result: model.bidResult, isRevealing: model.isRevealing,
                               phase: phase)
                }
            }
        case .higherLower(let r)?:
            if let top = model.dataset.artwork(r.top), let bottom = model.dataset.artwork(r.bottom) {
                PricierPair(round: r, top: top, bottom: bottom, outcome: model.outcome,
                            isRevealing: model.isRevealing, phase: phase) { side in
                    if model.isRevealing { tapArtwork() } else { submit(.higherLower(side: side)) }
                }
                .padding(.top, Tokens.Space.s)
            }
        default:
            EmptyView()
        }
    }

    private var bottomBar: some View {
        SessionBottomBar {
            if model.stage == .intro {
                SessionActionButton(title: "Start round", identifier: "daily.start", style: .prominent) {
                    withArtAnimation(ArtMotion.entrance, reduceMotion: reduceMotion) { model.begin() }
                }
            } else if model.isRevealing {
                if model.reveal.phase >= .next {
                    SessionActionButton(
                        title: model.session.isFinished ? "See results" : "Next round", identifier: "session.next",
                        action: advance)
                    .transition(.opacity)
                }
            } else if case .bid? = model.round {
                SessionActionButton(title: "Place bid", identifier: "bid.place", style: .prominent) {
                    submit(.bid(position: model.bidPosition))
                }
            }
        }
    }

    private func submit(_ answer: Answer) {
        guard let outcome = model.answer(answer) else { return }
        app.prefetch(model.upcomingArtworks)
        model.reveal.start(isHit: outcome.isCorrect == true, reduceMotion: reduceMotion,
                           announcement: outcome.isCorrect == true ? "Correct." : "Not this time.")
    }

    private func tapArtwork() {
        guard model.isRevealing else { return }
        if model.reveal.phase < .next { model.reveal.skipToEnd() } else { advance() }
    }

    private func advance() {
        showsClue = false
        withArtAnimation(ArtMotion.entrance, reduceMotion: reduceMotion) { model.advance() }
    }

    private func autoPlayIfRequested() async {
        guard app.debug.autoAnswer, model.session.index == 0 else { return }
        try? await Task.sleep(for: .seconds(1))
        model.playThrough { $0.bestAnswer() }
    }
}

/// "Round 3 · Bid" card shown before each round.
struct DailyIntroCard: View {
    let model: DailyModel

    var body: some View {
        // Centred when it fits; scrolls at large Dynamic Type sizes instead of truncating.
        ViewThatFits(in: .vertical) {
            card
            ScrollView { card }
        }
    }

    private var card: some View {
        VStack(spacing: Tokens.Space.l) {
            Spacer(minLength: 0)
            Text("Daily Challenge · Day \(model.dayNumber)\(model.isPractice ? " · practice" : "")")
                .artTextStyle(Tokens.Typography.provenance)
                .foregroundStyle(Tokens.Color.textSecondary)
            Text(model.introTitle)
                .artTextStyle(Tokens.Typography.displayL)
                .foregroundStyle(Tokens.Color.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("daily.introTitle")
            if let round = model.round {
                Text(DailyModel.kindHint(round))
                    .artTextStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            DailyMarksRow(marks: model.marks, total: model.totalRounds)
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Five tiles: ◆ / ◇ / ▢ for played rounds, a hairline square for rounds to come.
struct DailyMarksRow: View {
    let marks: [ShareMark]
    let total: Int

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            ForEach(0..<total, id: \.self) { i in
                if i < marks.count {
                    Image(systemName: marks[i].symbol)
                        .foregroundStyle(marks[i] == .miss ? Tokens.Color.textSecondary : Tokens.Color.accentGilt)
                } else {
                    Image(systemName: "square.dashed").foregroundStyle(Tokens.Color.lineHairline)
                }
            }
        }
        .font(.title2.weight(.medium))
        .accessibilityElement()
        .accessibilityLabel(marks.isEmpty ? "No rounds played yet" : marks.map(\.label).joined(separator: ", "))
    }
}
