import ArtCore
import ArtData
import ArtDesign
import Foundation
import Observation

/// "Pick the price": 10 rounds (3 easy, 4 medium, 3 hard), four ascending options, streak bonus.
@Observable
final class PickPriceModel {
    private(set) var play: PlaySession
    /// Index chosen in the round being revealed.
    private(set) var chosenIndex: Int?
    /// Drives the shared hammer reveal for the current round.
    let reveal = HammerRevealDriver()

    @ObservationIgnored let dataset: any DatasetProviding
    @ObservationIgnored private let profile: ProfileModel

    init(context: SessionContext) throws {
        let dataset = context.dataset
        let profile = context.profile
        self.dataset = dataset
        self.profile = profile
        play = PlaySession(game: try context.makeSession(.pickPrice))
    }

    var session: GameSession { play.game }

    /// The round on screen.
    var round: PickPriceRound? {
        if case .pickPrice(let r)? = play.displayedRound { return r }
        return nil
    }

    var artwork: Artwork? { round.flatMap { dataset.artwork($0.artwork) } }

    var price: PriceRecord? {
        guard let round, let artwork else { return nil }
        return artwork.price(id: round.priceID)
    }

    var outcome: RoundOutcome? { play.revealedOutcome }
    var isRevealing: Bool { play.isRevealing }
    var isOver: Bool { play.isOver }
    var progress: SessionProgress { .lots(current: min(play.displayIndex + 1, totalRounds), total: totalRounds) }
    var totalRounds: Int { session.rounds.count }

    /// Next round's artwork (prefetched as soon as the player answers).
    var upcomingArtworks: [Artwork] {
        (play.upcomingRound?.artworkIDs ?? []).compactMap(dataset.artwork)
    }

    /// Answers the current round; records it and, on the last round, the session.
    @discardableResult
    func choose(_ index: Int) -> RoundOutcome? {
        guard let submitted = play.submit(.pickPrice(index: index)) else { return nil }
        let (roundIndex, outcome) = submitted
        chosenIndex = index
        profile.recordRound(of: session, at: roundIndex)
        if session.isFinished {
            profile.recordSession(mode: .pickPrice, points: session.totalPoints, longestStreak: play.longestStreak)
        }
        return outcome
    }

    /// Ends the reveal and shows the next round (or the summary).
    func advance() {
        reveal.reset()
        chosenIndex = nil
        play.advance()
    }

    var correctCount: Int { session.outcomes.filter { $0.isCorrect == true }.count }

    func summary() -> SessionSummary {
        let marks: [ShareMark] = session.outcomes.map { $0.isCorrect == true ? .hit : .miss }
        // Feature the priciest work the player got right, else the first work.
        let rightIDs = zip(session.rounds, session.outcomes).compactMap { round, outcome -> PickPriceRound? in
            guard outcome.isCorrect == true, case .pickPrice(let r) = round else { return nil }
            return r
        }
        let best = rightIDs.max { $0.options[$0.correctIndex] < $1.options[$1.correctIndex] }
        let featuredID = best?.artwork ?? session.rounds.first?.artworkIDs.first
        return SessionSummary(
            mode: .pickPrice, headline: "\(correctCount)/\(totalRounds)",
            caption: "Pick the price · \(session.totalPoints) points",
            detail: play.longestStreak >= Scorer.streakBonusFrom ? "Longest streak \(play.longestStreak)" : nil,
            marks: marks, featured: featuredID.flatMap(dataset.artwork))
    }
}
