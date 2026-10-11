import ArtCore
import ArtData
import ArtDesign
import Foundation
import Observation

/// "Which is pricier?": endless higher-or-lower chain on inflation-adjusted prices; one miss ends
/// the run. The best streak is persisted through `ModeStats.bestStreak`.
@Observable
final class PricierModel {
    private(set) var play: PlaySession
    private(set) var chosenSide: PricierSide?
    let reveal = HammerRevealDriver()
    /// Personal best before this run.
    let previousBest: Int

    @ObservationIgnored let dataset: any DatasetProviding
    @ObservationIgnored private let profile: ProfileModel
    @ObservationIgnored private var sessionRecorded = false

    init(context: SessionContext) throws {
        let dataset = context.dataset
        let profile = context.profile
        self.dataset = dataset
        self.profile = profile
        previousBest = profile.stats(.higherLower).bestStreak
        play = PlaySession(game: try context.makeSession(.higherLower))
    }

    var session: GameSession { play.game }

    var round: HigherLowerRound? {
        if case .higherLower(let r)? = play.displayedRound { return r }
        return nil
    }

    var top: Artwork? { round.flatMap { dataset.artwork($0.top) } }
    var bottom: Artwork? { round.flatMap { dataset.artwork($0.bottom) } }
    var outcome: RoundOutcome? { play.revealedOutcome }
    var isRevealing: Bool { play.isRevealing }
    var isOver: Bool { play.isOver }
    /// Current run length (correct answers in a row).
    var streak: Int { session.streak }
    var bestStreak: Int { max(previousBest, play.longestStreak) }
    var isPersonalBest: Bool { play.longestStreak > previousBest }
    var upcomingArtworks: [Artwork] { (play.upcomingRound?.artworkIDs ?? []).compactMap(dataset.artwork) }

    func artwork(_ side: PricierSide) -> Artwork? { side == .top ? top : bottom }

    /// Taps a frame as the pricier work.
    @discardableResult
    func choose(_ side: PricierSide) -> RoundOutcome? {
        guard let submitted = play.submit(.higherLower(side: side)) else { return nil }
        chosenSide = side
        play.extendIfNeeded(dataset: dataset)
        profile.recordRound(of: session, at: submitted.index)
        if session.isFinished { recordSession() }
        return submitted.outcome
    }

    func advance() {
        reveal.reset()
        chosenSide = nil
        play.advance()
    }

    /// Called when the player leaves mid-run: the run so far still counts toward the best streak.
    func quit() {
        if !session.outcomes.isEmpty { recordSession() }
    }

    private func recordSession() {
        guard !sessionRecorded else { return }
        sessionRecorded = true
        profile.recordSession(mode: .higherLower, points: session.totalPoints, longestStreak: play.longestStreak)
    }

    func summary() -> SessionSummary {
        let marks: [ShareMark] = session.outcomes.map { $0.isCorrect == true ? .hit : .miss }
        let featured = session.rounds.prefix(session.outcomes.count).last.flatMap { round -> Artwork? in
            guard case .higherLower(let r) = round else { return nil }
            return dataset.artwork(r.pricier)
        }
        return SessionSummary(
            mode: .higherLower, headline: "Streak \(play.longestStreak)",
            caption: "Which is pricier? · best \(bestStreak)",
            detail: isPersonalBest ? "New personal best" : nil, marks: marks, featured: featured,
            isPersonalBest: isPersonalBest)
    }
}
