import ArtCore
import ArtData
import Foundation

/// App-side bookkeeping around an ArtCore `GameSession`: which round is on screen (the answered
/// one stays visible during its reveal) and the longest streak reached.
struct PlaySession {
    private(set) var game: GameSession
    /// True between an answer and `advance()`.
    private(set) var isRevealing = false
    private(set) var longestStreak = 0

    init(game: GameSession) {
        self.game = game
    }

    /// Index of the round on screen.
    var displayIndex: Int { isRevealing ? game.index - 1 : game.index }

    /// The round on screen (nil once a finished session has advanced past its last reveal).
    var displayedRound: Round? {
        game.rounds.indices.contains(displayIndex) ? game.rounds[displayIndex] : nil
    }

    /// The outcome being revealed.
    var revealedOutcome: RoundOutcome? { isRevealing ? game.outcomes.last : nil }

    /// The answer being revealed.
    var revealedAnswer: Answer? { isRevealing ? game.answers.last : nil }

    /// The round after the one on screen, if already generated (for image prefetch).
    var upcomingRound: Round? {
        let next = displayIndex + 1
        return game.rounds.indices.contains(next) ? game.rounds[next] : nil
    }

    /// True when the last reveal of a finished session has been dismissed.
    var isOver: Bool { game.isFinished && !isRevealing }

    /// Scores `answer`; returns the answered index and outcome, or nil if not accepting answers.
    mutating func submit(_ answer: Answer) -> (index: Int, outcome: RoundOutcome)? {
        guard !isRevealing, game.currentRound != nil else { return nil }
        let index = game.index
        guard let outcome = game.submit(answer) else { return nil }
        isRevealing = true
        longestStreak = max(longestStreak, game.streak)
        return (index, outcome)
    }

    /// For endless sessions: generates the next batch when needed.
    mutating func extendIfNeeded(dataset: any DatasetProviding) {
        SessionFactory.extendIfNeeded(&game, dataset: dataset)
    }

    /// Leaves the reveal and moves to the next round (or the summary).
    mutating func advance() {
        isRevealing = false
    }
}
