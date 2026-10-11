import ArtCore
import ArtData
import ArtDesign
import Foundation
import Observation

/// The daily challenge: five seeded rounds of mixed kinds, identical for every player; each round
/// opens with an intro card. Replays of a completed day are practice (no streak or score change).
@Observable
final class DailyModel {
    enum Stage: Equatable { case intro, playing }

    private(set) var play: PlaySession
    private(set) var stage: Stage = .intro
    let day: DayKey
    /// True when today was already completed before this run.
    let isPractice: Bool
    let reveal = HammerRevealDriver()

    /// Pick / category answer being revealed.
    private(set) var chosenIndex: Int?
    /// Bid slider position for the current bid round.
    var bidPosition: Int
    private(set) var bidResult: BidResult?
    let bidBounds: ClosedRange<Int>

    @ObservationIgnored let dataset: any DatasetProviding
    @ObservationIgnored private let profile: ProfileModel

    init(context: SessionContext) throws {
        dataset = context.dataset
        profile = context.profile
        let today = try DailyService.today(provider: context.dayProvider, dataset: context.dataset,
                                           profile: context.profile.profile)
        day = today.challenge.day
        isPractice = today.status.isCompleted
        play = PlaySession(game: today.challenge.session)
        bidBounds = BidModel.sliderBounds(context.dataset.pricedArtworks.compactMap { $0.gamePrice?.log10UsdNominalMilli })
        bidPosition = (bidBounds.lowerBound + bidBounds.upperBound) / 2
    }

    var session: GameSession { play.game }
    var round: Round? { play.displayedRound }
    var outcome: RoundOutcome? { play.revealedOutcome }
    var isRevealing: Bool { play.isRevealing }
    var isOver: Bool { play.isOver }
    var totalRounds: Int { session.rounds.count }
    var roundNumber: Int { min(play.displayIndex + 1, totalRounds) }
    var progress: SessionProgress { .lots(current: roundNumber, total: totalRounds) }
    var dayNumber: Int { HomeContent.dailyNumber(on: day) }
    var upcomingArtworks: [Artwork] { (play.upcomingRound?.artworkIDs ?? []).compactMap(dataset.artwork) }

    /// "Round 3 · Bid".
    var introTitle: String { "Round \(roundNumber) · \(round.map(Self.kindTitle) ?? "")" }

    static func kindTitle(_ round: Round) -> String {
        switch round.kind {
        case .pickPrice: "Pick the price"
        case .higherLower: "Which is pricier?"
        case .category: "Category quiz"
        case .bid: "Bid"
        case .swipe: "Swipe"
        }
    }

    static func kindHint(_ round: Round) -> String {
        switch round.kind {
        case .pickPrice: "Four estimates. One is the sale price."
        case .higherLower: "Two works. Tap the one that sold for more."
        case .category: "Name the movement or medium."
        case .bid: "Slide to your estimate and place a bid."
        case .swipe: ""
        }
    }

    func begin() {
        stage = .playing
    }

    /// Answers the current round with any answer kind.
    @discardableResult
    func answer(_ answer: Answer) -> RoundOutcome? {
        guard stage == .playing, let current = session.currentRound else { return nil }
        guard let submitted = play.submit(answer) else { return nil }
        switch answer {
        case .pickPrice(let i), .category(let i): chosenIndex = i
        case .bid(let p):
            if case .bid(let r) = current { bidResult = BidScorer.score(position: p, actualMilli: r.actualMilli) }
        default: break
        }
        profile.recordRound(of: session, at: submitted.index, day: day)
        if session.isFinished && !isPractice {
            profile.recordDailyCompletion(of: session, on: day)
        }
        return submitted.outcome
    }

    func advance() {
        reveal.reset()
        chosenIndex = nil
        bidResult = nil
        bidPosition = (bidBounds.lowerBound + bidBounds.upperBound) / 2
        play.advance()
        stage = .intro
    }

    /// The answer that scores best for the current round (DEBUG autoplay and tests).
    func bestAnswer() -> Answer? {
        switch session.currentRound {
        case .pickPrice(let r)?: .pickPrice(index: r.correctIndex)
        case .higherLower(let r)?: .higherLower(side: r.pricierSide)
        case .category(let r)?: .category(index: r.correctIndex)
        case .bid(let r)?: .bid(position: BidScorer.position(forMilli: r.actualMilli))
        case .swipe?: .swipe(liked: true)
        case nil: nil
        }
    }

    /// Plays every remaining round with `answers` (DEBUG screenshots, tests).
    func playThrough(_ pick: (DailyModel) -> Answer?) {
        while !isOver {
            begin()
            guard let a = pick(self) else { break }
            answer(a)
            advance()
        }
    }

    // MARK: Result

    var total: Int { session.totalPoints }
    static let maxTotal = 500

    /// ◆ correct (bid within 2×) · ◇ close (bid within 10×) · ▢ miss.
    var marks: [ShareMark] {
        session.outcomes.map { outcome in
            switch outcome.bidTier {
            case .bullseye?, .expertEye?: return .hit
            case .goodInstinct?, .inTheRoom?: return .close
            case .offTheWall?: return .miss
            case nil: return outcome.isCorrect == true ? .hit : .miss
            }
        }
    }

    /// Streak shown on the result (after recording today's completion).
    var streak: Int { profile.profile.daily.displayedStreak(today: day) }

    /// "GTP of Art · Day 1 · 410/500 ◆◆◇◆▢" (text share fallback).
    var shareText: String {
        "\(AppInfo.wordmark) · Day \(dayNumber) · \(total)/\(Self.maxTotal) "
            + marks.map(DailyModel.glyph).joined()
    }

    static func glyph(_ mark: ShareMark) -> String {
        switch mark {
        case .hit: "◆"
        case .close: "◇"
        case .miss: "▢"
        }
    }

    func summary() -> SessionSummary {
        SessionSummary(
            mode: .daily, headline: "\(total)/\(Self.maxTotal)",
            caption: "Daily Challenge · Day \(dayNumber)\(isPractice ? " · practice" : "")",
            detail: nil, marks: marks, featured: session.rounds.last?.artworkIDs.first.flatMap(dataset.artwork),
            shareText: shareText)
    }
}
