import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Bid / estimate: artwork, 48pt live bid, log slider, gilt "Place bid"; reveal with pin, tier
/// brackets, tier label and "You were 3.1× under".
struct BidView: View {
    @Bindable var model: BidModel
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
                if let round = model.round, let price = model.price, let artwork = model.artwork {
                    BidAnswers(
                        round: round, price: price, artwork: artwork, position: $model.position,
                        bounds: model.bounds, result: model.result, isRevealing: model.isRevealing,
                        phase: model.reveal.phase)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            SessionBottomBar {
                if model.isRevealing {
                    if model.reveal.phase >= .next {
                        SessionActionButton(
                            title: model.session.isFinished ? "See results" : "Next lot", identifier: "session.next",
                            action: advance)
                        .transition(.opacity)
                    }
                } else {
                    SessionActionButton(title: "Place bid", identifier: "bid.place", style: .prominent, action: placeBid)
                }
            }
        }
        .revealHaptics(model.reveal)
        .task(id: model.session.index) { await autoAnswerIfRequested() }
    }

    private func placeBid() {
        guard let outcome = model.placeBid(), let result = model.result else { return }
        app.prefetch(model.upcomingArtworks)
        let price = model.price.map { PriceCopy.provenance($0, showVenue: true) } ?? ""
        model.reveal.start(
            isHit: outcome.isCorrect == true, reduceMotion: reduceMotion,
            announcement: SpokenPrice.text("\(result.tier.title). \(PriceCopy.bidRatio(result)) \(price)."))
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
        if app.debug.autoBest, let round = model.round {
            // Slider position p ↔ 2000 + 10p milli-decades; land ~1.2× over the sale price.
            let best = (round.actualMilli - LogPriceScale.baseMilli) / LogPriceScale.milliPerPosition
            model.position = min(max(best + 8, model.bounds.lowerBound), model.bounds.upperBound)
        }
        placeBid()
    }
}

/// Bid answer zone (also used by the daily): question, live bid and slider; the reveal (rolling
/// price, labelled track, tier and ratio, provenance) occupies the same space.
struct BidAnswers: View {
    let round: BidRound
    let price: PriceRecord
    let artwork: Artwork
    @Binding var position: Int
    let bounds: ClosedRange<Int>
    let result: BidResult?
    let isRevealing: Bool
    let phase: RevealPhase

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        PhaseLayers(isRevealing: isRevealing) { bidding } reveal: { reveal }
    }

    private var bidLabel: String { LogPriceScale.label(forPosition: position) }

    // The zone is as tall as the reveal (`PhaseLayers`), which has more rows than the question.
    // Spacers spread question, bid and slider over that height instead of leaving a void above.
    private var bidding: some View {
        VStack(spacing: 0) {
            Text(PriceCopy.question(price))
                .artTextStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textPrimary)
                .multilineTextAlignment(.center)
            Spacer(minLength: Tokens.Space.m)
            Text(bidLabel)
                .artTextStyle(Tokens.Typography.priceHero)
                .monospacedDigit()
                .foregroundStyle(Tokens.Color.accentGilt)
                .contentTransition(.numericText(value: Double(position)))
                .animation(ArtMotion.fast, value: position)
                .accessibilityLabel("Your bid \(SpokenPrice.text(bidLabel))")
                .accessibilityIdentifier("bid.live")
            Spacer(minLength: Tokens.Space.m)
            LogSlider(position: $position, bounds: bounds)
                .accessibilityIdentifier("bid.slider")
        }
        .frame(maxHeight: .infinity)
    }

    private var reveal: some View {
        let shown = result ?? BidScorer.score(position: position, actualMilli: round.actualMilli)
        return VStack(spacing: Tokens.Space.s) {
            RevealPrice(guess: LogPriceScale.displayPrice(forPosition: shown.position), actual: Double(round.actualUSD),
                        finalText: PriceFormatter.format(price, basis: .nominal), phase: phase)
                .artTextStyle(Tokens.Typography.priceHero)
                .foregroundStyle(Tokens.Color.accentGilt)
                .revealSettle(phase: phase)
                .accessibilityIdentifier("reveal.price")
            BidRevealTrack(bounds: bounds, guessPosition: shown.position, actualMilli: round.actualMilli, phase: phase)
                // A positional diagram across one track width: past AX1 its labels cannot fit. The
                // price, tier and ratio around it scale fully and VoiceOver reads it as one sentence.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            // Tier and ratio side by side; stacked at accessibility sizes so neither truncates.
            let row = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: Tokens.Space.xs)) : AnyLayout(HStackLayout(spacing: Tokens.Space.s))
            row {
                Label(shown.tier.title, systemImage: shown.tier.symbolName)
                    .foregroundStyle(shown.tier == .offTheWall ? Tokens.Color.feedbackMiss : Tokens.Color.feedbackHit)
                    .accessibilityIdentifier("bid.tier")
                Text("\(PriceCopy.bidRatio(shown)) +\(shown.points)")
                    .foregroundStyle(Tokens.Color.textPrimary)
            }
            .artTextStyle(Tokens.Typography.label)
            .revealProvenance(phase: phase)
            ProvenanceLine(artwork: artwork, record: price)
                .revealProvenance(phase: phase)
        }
    }
}
