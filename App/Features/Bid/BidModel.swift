import ArtCore
import ArtData
import ArtDesign
import Foundation
import Observation

/// "Bid / estimate": 10 rounds on the log slider; integer milli-decade tiers (plan Part F).
@Observable
final class BidModel {
    private(set) var play: PlaySession
    /// Slider position 0…700 (`guessMilli = 2000 + 10·p`).
    var position: Int
    /// The scored bid being revealed.
    private(set) var result: BidResult?
    let reveal = HammerRevealDriver()
    /// Slider range rounded out to whole decades around the dataset's prices.
    let bounds: ClosedRange<Int>

    @ObservationIgnored let dataset: any DatasetProviding
    @ObservationIgnored private let profile: ProfileModel
    @ObservationIgnored private var results: [BidResult] = []

    init(context: SessionContext) throws {
        let dataset = context.dataset
        let profile = context.profile
        self.dataset = dataset
        self.profile = profile
        play = PlaySession(game: try context.makeSession(.bid))
        bounds = Self.sliderBounds(dataset.pricedArtworks.compactMap { $0.gamePrice?.log10UsdNominalMilli })
        position = (bounds.lowerBound + bounds.upperBound) / 2
    }

    /// Decade-aligned slider bounds covering every price (fallback $10K–$1B).
    static func sliderBounds(_ millis: [Int]) -> ClosedRange<Int> {
        guard let low = millis.min(), let high = millis.max() else { return 200...700 }
        let per = LogPriceScale.positionsPerDecade
        let lowPos = LogPriceScale.clamp(((low - LogPriceScale.baseMilli) / LogPriceScale.milliPerPosition) / per * per)
        let highRaw = (high - LogPriceScale.baseMilli + LogPriceScale.milliPerPosition - 1) / LogPriceScale.milliPerPosition
        let highPos = LogPriceScale.clamp((highRaw + per - 1) / per * per)
        return lowPos < highPos ? lowPos...highPos : 200...700
    }

    var session: GameSession { play.game }

    var round: BidRound? {
        if case .bid(let r)? = play.displayedRound { return r }
        return nil
    }

    var artwork: Artwork? { round.flatMap { dataset.artwork($0.artwork) } }
    var price: PriceRecord? { round.flatMap { r in artwork?.price(id: r.priceID) } }
    var outcome: RoundOutcome? { play.revealedOutcome }
    var isRevealing: Bool { play.isRevealing }
    var isOver: Bool { play.isOver }
    var totalRounds: Int { session.rounds.count }
    var progress: SessionProgress { .lots(current: min(play.displayIndex + 1, totalRounds), total: totalRounds) }
    var upcomingArtworks: [Artwork] { (play.upcomingRound?.artworkIDs ?? []).compactMap(dataset.artwork) }

    /// The live bid label, e.g. "$2.5M".
    var bidLabel: String { LogPriceScale.label(forPosition: position) }

    /// Scores the current position.
    @discardableResult
    func placeBid() -> RoundOutcome? {
        guard let round, let submitted = play.submit(.bid(position: position)) else { return nil }
        let (roundIndex, outcome) = submitted
        let scored = BidScorer.score(position: position, actualMilli: round.actualMilli)
        result = scored
        results.append(scored)
        profile.recordRound(of: session, at: roundIndex)
        if session.isFinished {
            profile.recordSession(mode: .bid, points: session.totalPoints, longestStreak: play.longestStreak)
        }
        return outcome
    }

    func advance() {
        reveal.reset()
        result = nil
        position = (bounds.lowerBound + bounds.upperBound) / 2
        play.advance()
    }

    func summary() -> SessionSummary {
        let meanError = results.isEmpty ? 0 : results.map(\.errorMilli).reduce(0, +) / results.count
        let average = DisplayMath.pow10(Double(meanError) / 1000)
        let bestIndex = results.indices.min { results[$0].errorMilli < results[$1].errorMilli }
        var detail: String?
        var featured: Artwork?
        if let bestIndex, session.rounds.indices.contains(bestIndex), let id = session.rounds[bestIndex].artworkIDs.first {
            featured = dataset.artwork(id)
            let percent = Int(((results[bestIndex].factor - 1) * 100).rounded())
            detail = "Best: within \(max(percent, 1))% on \(featured?.title ?? "a lot")"
        }
        let marks: [ShareMark] = results.map { r in
            switch r.tier {
            case .bullseye, .expertEye: .hit
            case .goodInstinct, .inTheRoom: .close
            case .offTheWall: .miss
            }
        }
        return SessionSummary(
            mode: .bid, headline: "Average miss \(PriceCopy.multiplier(average))×",
            caption: "Bid · \(session.totalPoints) points", detail: detail, marks: marks, featured: featured)
    }
}

extension BidTier {
    var title: String {
        switch self {
        case .bullseye: "Bullseye"
        case .expertEye: "Expert eye"
        case .goodInstinct: "Good instinct"
        case .inTheRoom: "In the room"
        case .offTheWall: "Off the wall"
        }
    }

    var symbolName: String {
        switch self {
        case .bullseye: "scope"
        case .expertEye: "eye"
        case .goodInstinct: "lightbulb"
        case .inTheRoom: "person.2"
        case .offTheWall: "arrow.up.and.down"
        }
    }
}
