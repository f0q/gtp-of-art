import ArtCore
import ArtData
import ArtDesign
import Foundation
import Observation

/// One card in the swipe stack.
struct SwipeCardItem: Identifiable, Equatable {
    let artwork: Artwork
    var id: ArtworkID { artwork.id }
}

/// Swipe → taste (plan C4): 20 cards, like/pass, one-level undo, no prices.
///
/// Each swipe updates the live `taste` with `TasteProfile.applying`; undo inverts it with
/// `undoing`. The swipe stays *pending* until the next swipe (or the end of the session) closes its
/// undo window; only then is it applied to the stored profile and its `RoundRecord` appended
/// (ArtData: swipe records are appended once the undo window has closed).
@Observable
final class SwipeModel {
    /// A swipe still inside its undo window.
    struct Pending: Equatable {
        let roundIndex: Int
        let swipe: TasteSwipe
        /// The session before this swipe (GameSession has no undo; it is a value, so restore it).
        let before: GameSession
    }

    private(set) var game: GameSession
    private(set) var pending: Pending?
    /// Stored taste plus the pending swipe.
    private(set) var taste: TasteProfile
    /// Set once the last card is swiped and everything is recorded.
    private(set) var reading: TasteReading?

    @ObservationIgnored let dataset: any DatasetProviding
    @ObservationIgnored private let profile: ProfileModel
    @ObservationIgnored private let palettes: PaletteIndex
    @ObservationIgnored let stack = CardStackController()

    /// - Parameter prior: the onboarding prior (weighted picks); swipe ignores difficulty.
    init(
        dataset: any DatasetProviding, profile: ProfileModel, seed: UInt64, prior: TastePrior?,
        palettes: PaletteIndex = .bundled
    ) throws {
        self.dataset = dataset
        self.profile = profile
        self.palettes = palettes
        game = try SessionFactory.make(mode: .swipe, dataset: dataset, seed: seed, prior: prior)
        taste = profile.profile.taste
    }

    convenience init(context: SessionContext) throws {
        try self.init(dataset: context.dataset, profile: context.profile, seed: context.seed, prior: context.prior)
    }

    var total: Int { game.rounds.count }
    /// Cards swiped so far (including a pending one).
    var swipedCount: Int { game.index }
    /// 1-based number of the card on top.
    var currentCard: Int { min(swipedCount + 1, total) }
    var isFinished: Bool { reading != nil }
    var canUndo: Bool { pending != nil && !isFinished }
    var progressCopy: String? { isFinished ? nil : TasteCopy.progress(card: currentCard, total: total) }

    /// Remaining cards, top first.
    var deck: [SwipeCardItem] {
        guard game.index < game.rounds.count else { return [] }
        return game.rounds[game.index...].compactMap { round in
            round.artworkIDs.first.flatMap(dataset.artwork).map(SwipeCardItem.init)
        }
    }

    var topArtwork: Artwork? { deck.first?.artwork }

    /// The next three works after the top card (prefetched).
    var upcomingArtworks: [Artwork] { Array(deck.dropFirst().prefix(3).map(\.artwork)) }

    /// Liked works this session, in swipe order.
    var likedArtworks: [Artwork] {
        zip(game.rounds, game.answers).compactMap { round, answer in
            guard case .swipe(liked: true) = answer else { return nil }
            return round.artworkIDs.first.flatMap(dataset.artwork)
        }
    }

    /// Likes (true) / passes for the top card. Returns false when no card is waiting.
    @discardableResult
    func swipe(liked: Bool) -> Bool {
        guard !isFinished, let artwork = topArtwork else { return false }
        commitPending()
        let before = game
        let index = game.index
        guard game.submit(.swipe(liked: liked)) != nil else { return false }
        let swipe = TasteSwipe(artwork: artwork, liked: liked)
        taste = taste.applying(swipe)
        pending = Pending(roundIndex: index, swipe: swipe, before: before)
        if game.isFinished { finish() }
        return true
    }

    /// Restores the last card (one level). Returns false if there is nothing to undo.
    @discardableResult
    func undo() -> Bool {
        guard canUndo, let p = pending else { return false }
        taste = taste.undoing(p.swipe)
        game = p.before
        pending = nil
        return true
    }

    /// Closes the undo window (call when leaving the session early).
    func close() {
        commitPending()
    }

    private func commitPending() {
        guard let p = pending else { return }
        pending = nil
        profile.recordSwipe(of: game, at: p.roundIndex, swipe: p.swipe)
    }

    private func finish() {
        commitPending()
        profile.recordSession(mode: .swipe, points: 0, longestStreak: 0)
        taste = profile.profile.taste
        let liked = likedArtworks
        reading = TasteReading(
            profile: taste, dataset: dataset, liked: liked, palettes: palettes,
            session: TasteSessionResult(liked: liked, swipes: game.answers.count))
    }
}
