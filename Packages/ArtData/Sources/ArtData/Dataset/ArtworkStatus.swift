import ArtCore

/// Lifecycle state of an artwork record (`artworks[].status`). ArtCore's `Artwork` does not carry
/// it, so ArtData reads it from a lightweight side decode.
public enum ArtworkStatus: String, Codable, Sendable, CaseIterable {
    /// Playable.
    case active
    /// Kept in the file but not shown (e.g. pending a rights check).
    case hidden
    /// Permanently withdrawn.
    case retired
}

/// The minimal per-artwork fields ArtData needs beyond ArtCore's `Artwork`.
struct ArtworkStatusEntry: Decodable {
    var id: ArtworkID
    var status: ArtworkStatus?
}

/// `dataset.json` decoded only for `status`.
struct ArtworkStatusFile: Decodable {
    var artworks: [ArtworkStatusEntry]
}
