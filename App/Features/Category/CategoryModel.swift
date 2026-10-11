import ArtCore
import ArtData
import ArtDesign
import Foundation
import Observation

/// Category quiz: 10 rounds, four category chips; accepted alternates count as correct.
@Observable
final class CategoryModel {
    private(set) var play: PlaySession
    private(set) var chosenIndex: Int?
    let reveal = HammerRevealDriver()

    @ObservationIgnored let dataset: any DatasetProviding
    @ObservationIgnored private let profile: ProfileModel

    init(context: SessionContext) throws {
        dataset = context.dataset
        profile = context.profile
        play = PlaySession(game: try context.makeSession(.category))
    }

    var session: GameSession { play.game }

    var round: CategoryRound? {
        if case .category(let r)? = play.displayedRound { return r }
        return nil
    }

    var artwork: Artwork? { round.flatMap { dataset.artwork($0.artwork) } }
    var outcome: RoundOutcome? { play.revealedOutcome }
    var isRevealing: Bool { play.isRevealing }
    var isOver: Bool { play.isOver }
    var totalRounds: Int { session.rounds.count }
    var progress: SessionProgress { .lots(current: min(play.displayIndex + 1, totalRounds), total: totalRounds) }
    var upcomingArtworks: [Artwork] { (play.upcomingRound?.artworkIDs ?? []).compactMap(dataset.artwork) }

    /// Chip labels for the round on screen.
    var optionLabels: [String] {
        round?.options.map { CategoryCopy.label($0, dataset: dataset) } ?? []
    }

    /// The true category of the round on screen.
    var truth: ArtCore.Category? { round.flatMap { dataset.category($0.options[$0.correctIndex]) } }

    @discardableResult
    func choose(_ index: Int) -> RoundOutcome? {
        guard let submitted = play.submit(.category(index: index)) else { return nil }
        chosenIndex = index
        profile.recordRound(of: session, at: submitted.index)
        if session.isFinished {
            profile.recordSession(mode: .category, points: session.totalPoints, longestStreak: play.longestStreak)
        }
        return submitted.outcome
    }

    func advance() {
        reveal.reset()
        chosenIndex = nil
        play.advance()
    }

    var correctCount: Int { session.outcomes.filter { $0.isCorrect == true }.count }

    func summary() -> SessionSummary {
        let marks: [ShareMark] = session.outcomes.map {
            switch $0.categoryMatch {
            case .correct?: .hit
            case .alternate?: .close
            default: .miss
            }
        }
        // Up to three distinct categories the player named correctly, for the share card.
        var mastered: [String] = []
        for (round, outcome) in zip(session.rounds, session.outcomes) where outcome.isCorrect == true {
            guard case .category(let r) = round else { continue }
            let label = CategoryCopy.label(r.options[r.correctIndex], dataset: dataset)
            if !mastered.contains(label) { mastered.append(label) }
        }
        let featured = zip(session.rounds, session.outcomes).first { $0.1.isCorrect == true }?.0.artworkIDs.first
            ?? session.rounds.first?.artworkIDs.first
        return SessionSummary(
            mode: .category, headline: "\(correctCount)/\(totalRounds)",
            caption: "Movements mastered · \(session.totalPoints) points",
            detail: mastered.isEmpty ? nil : mastered.prefix(3).joined(separator: " · "),
            marks: marks, featured: featured.flatMap(dataset.artwork),
            shareCaption: mastered.isEmpty ? nil : "Movements mastered \(correctCount)/\(totalRounds) · "
                + mastered.prefix(3).joined(separator: " · "))
    }
}

/// Category strings (pure).
nonisolated enum CategoryCopy {
    static func label(_ id: CategoryID, dataset: any DatasetProviding) -> String {
        dataset.category(id)?.label ?? id.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// The note under a revealed answer.
    static func note(for outcome: RoundOutcome, round: CategoryRound, chosen: Int, dataset: any DatasetProviding)
        -> String
    {
        let truth = label(round.options[round.correctIndex], dataset: dataset)
        switch outcome.categoryMatch {
        case .correct?: return "Correct: \(truth)."
        case .alternate?:
            return "Also accepted: \(label(round.options[chosen], dataset: dataset)). The main answer is \(truth)."
        default: return "It's \(truth)."
        }
    }
}
