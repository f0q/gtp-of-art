import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Category quiz: artwork zone (zooms 1.6× to the focus point on "See the clue"), 2×2 chips
/// (1×4 at accessibility sizes), teaching line on reveal.
struct CategoryView: View {
    @Bindable var model: CategoryModel
    let actions: SessionActions

    @Environment(\.app) private var app
    @Environment(\.artReduceMotion) private var reduceMotion
    @State private var showsClue = false

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
                if let artwork = model.artwork {
                    CategoryArtZone(artwork: artwork, showsClue: showsClue, onTap: tapArtwork)
                }
            } answers: {
                if let round = model.round, let artwork = model.artwork {
                    CategoryAnswers(
                        round: round, artwork: artwork, labels: model.optionLabels, truth: model.truth,
                        chosenIndex: model.chosenIndex, outcome: model.outcome, isRevealing: model.isRevealing,
                        phase: model.reveal.phase, showsClue: $showsClue, onChoose: choose)
                }
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

    private func choose(_ index: Int) {
        guard let outcome = model.choose(index) else { return }
        app.prefetch(model.upcomingArtworks)
        let truth = model.truth?.label ?? ""
        model.reveal.start(
            isHit: outcome.isCorrect == true, reduceMotion: reduceMotion,
            announcement: "\(outcome.isCorrect == true ? "Correct" : "Not quite"). \(truth). \(model.truth?.teach ?? "")")
    }

    private func tapArtwork() {
        guard model.isRevealing else { return }
        if model.reveal.phase < .next { model.reveal.skipToEnd() } else { advance() }
    }

    private func advance() {
        showsClue = false
        withArtAnimation(ArtMotion.entrance, reduceMotion: reduceMotion) { model.advance() }
    }

    private func autoAnswerIfRequested() async {
        guard app.debug.autoAnswer, model.session.index == 0, !model.isRevealing else { return }
        try? await Task.sleep(for: .seconds(1.5))
        choose(model.round?.correctIndex ?? 0)
    }
}

/// The artwork, or (on "See the clue") a 1.6× detail around its focus point.
struct CategoryArtZone: View {
    let artwork: Artwork
    let showsClue: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack {
            ArtworkZone(artwork: artwork, onTap: onTap)
                .opacity(showsClue ? 0 : 1)
            if showsClue {
                ArtworkDetail(artwork: artwork, zoom: Tokens.Layout.clueZoom)
                    .artTransition(.scale(scale: 1 / Tokens.Layout.clueZoom).combined(with: .opacity))
                    .onTapGesture(perform: onTap)
                    .accessibilityElement()
                    .accessibilityLabel("Detail of \(artwork.title)")
            }
        }
    }
}

/// Category answer zone (also used by the daily).
struct CategoryAnswers: View {
    let round: CategoryRound
    let artwork: Artwork
    let labels: [String]
    let truth: ArtCore.Category?
    let chosenIndex: Int?
    let outcome: RoundOutcome?
    let isRevealing: Bool
    let phase: RevealPhase
    @Binding var showsClue: Bool
    let onChoose: (Int) -> Void

    @Environment(\.app) private var app
    @Environment(SettingsModel.self) private var settings
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.artReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Tokens.Space.m) {
            PhaseLayers(isRevealing: isRevealing) {
                Text(truth?.axis == .medium ? "Which medium is this?" : "Which movement is this?")
                    .artTextStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .accessibilityIdentifier("category.question")
            } reveal: {
                ResultBadge(isHit: outcome?.isCorrect == true,
                            hitText: outcome?.categoryMatch == .alternate ? "Accepted" : "Correct",
                            missText: "Not this time")
            }
            chips
            PhaseLayers(isRevealing: isRevealing) {
                Color.clear.frame(height: 0)
            } reveal: {
                teaching
            }
        }
    }

    private var chips: some View {
        let columns = typeSize.isAccessibilitySize ? 1 : 2
        let rows = stride(from: 0, to: labels.count, by: columns).map { Array($0..<min($0 + columns, labels.count)) }
        return VStack(spacing: Tokens.Space.m) {
            ForEach(rows, id: \.first) { row in
                HStack(spacing: Tokens.Space.m) {
                    ForEach(row, id: \.self) { index in
                        CategoryChip(label: labels[index], index: index, state: state(index)) {
                            onChoose(index)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(!isRevealing)
    }

    private func state(_ index: Int) -> CategoryChip.State {
        guard isRevealing, phase >= .settle else { return isRevealing && index == chosenIndex ? .chosen : .idle }
        if index == round.correctIndex { return .correct }
        if index == chosenIndex { return outcome?.categoryMatch == .alternate ? .accepted : .chosenWrong }
        return .dimmed
    }

    private var teaching: some View {
        VStack(spacing: Tokens.Space.xs) {
            if let outcome, let chosenIndex {
                Text(CategoryCopy.note(for: outcome, round: round, chosen: chosenIndex, dataset: app.dataset))
                    .artTextStyle(Tokens.Typography.label)
                    .foregroundStyle(Tokens.Color.textPrimary)
            }
            if let teach = truth?.teach {
                Text(teach)
                    .artTextStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .accessibilityIdentifier("category.teach")
            }
            HStack(spacing: Tokens.Space.s) {
                if let price = artwork.gamePrice {
                    Text(PriceCopy.provenance(price, showVenue: settings.settings.showAuctionHouses))
                        .artTextStyle(Tokens.Typography.provenance)
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
                Spacer(minLength: 0)
                Button(showsClue ? "Whole work" : "See the clue") {
                    withArtAnimation(ArtMotion.reveal, reduceMotion: reduceMotion) { showsClue.toggle() }
                }
                .artTextStyle(Tokens.Typography.label)
                .foregroundStyle(Tokens.Color.textPrimary)
                .frame(minHeight: Tokens.Size.minTarget)
                .accessibilityIdentifier("category.clue")
            }
        }
        .multilineTextAlignment(.center)
        .opacity(phase >= .dim ? 1 : 0)
        .animation(reduceMotion ? ArtMotion.crossfade : ArtMotion.entrance.delay(Tokens.Motion.Reveal.teachAt),
                   value: phase >= .dim)
    }
}

/// A category chip (`.artButtonStyle(.option)` + `.artOptionState`): the correct chip fills; the
/// player's own pick (wrong or accepted alternate) keeps the gilt outline; the rest dim.
struct CategoryChip: View {
    enum State { case idle, chosen, correct, accepted, chosenWrong, dimmed }

    let label: String
    let index: Int
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.xs) {
                if let symbol { Image(systemName: symbol) }
                Text(label).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .artButtonStyle(.option)
        .artOptionState(optionState)
        .overlay {
            if state == .chosen || state == .chosenWrong || state == .accepted {
                RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous)
                    .strokeBorder(Tokens.Color.accentGilt, lineWidth: Tokens.Space.xxs)
            }
        }
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("category.option.\(index)")
    }

    private var optionState: ArtOptionState {
        switch state {
        case .correct: .correct
        case .dimmed: .incorrect
        default: .normal
        }
    }

    private var symbol: String? {
        switch state {
        case .correct: "checkmark.circle.fill"
        case .accepted: "checkmark.circle"
        case .chosenWrong: "xmark.circle"
        default: nil
        }
    }

    private var accessibilityText: String {
        switch state {
        case .correct: "\(label), correct answer"
        case .accepted: "\(label), also accepted"
        case .chosenWrong: "\(label), your pick"
        default: label
        }
    }
}
