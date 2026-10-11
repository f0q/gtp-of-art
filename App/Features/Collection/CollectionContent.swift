import ArtCore
import ArtData
import Foundation

/// "Works you've seen": every playable work that appeared in any recorded round (pure).
nonisolated struct CollectionContent: Equatable, Sendable {
    /// Seen works, most recently seen first.
    let seen: [ArtworkID]
    /// Latest swipe decision per work (true = kept).
    let swipes: [ArtworkID: Bool]
    /// Playable works in the pool.
    let total: Int

    var discovered: Int { seen.count }
    /// "142 / 250 discovered".
    var header: String { "\(discovered) / \(total) discovered" }

    init(records: [RoundRecord], pool: GamePool) {
        var order: [ArtworkID] = []
        var seenSet = Set<ArtworkID>()
        var swipes: [ArtworkID: Bool] = [:]
        for record in records.reversed() {
            for id in record.round.artworkIDs where pool.artwork(id) != nil && !seenSet.contains(id) {
                seenSet.insert(id)
                order.append(id)
            }
            if case .swipe(let round) = record.round, swipes[round.artwork] == nil, let liked = record.outcome.liked {
                swipes[round.artwork] = liked
            }
        }
        seen = order
        self.swipes = swipes
        total = pool.artworks.count
    }

    static let empty = CollectionContent(records: [], pool: GamePool(artworks: [], categories: []))
}
