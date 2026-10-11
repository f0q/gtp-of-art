import ArtCore

/// Availability of a content pack. MVP packs are always `bundled`; the other states are reserved
/// for phase-2 downloadable packs.
public enum PackState: Sendable, Equatable {
    case bundled
    case downloadable
    /// Download in progress, 0…1.
    case downloading(progress: Double)
    case failed
}

/// A department presented as a content pack (plan Part I1).
public struct ContentPack: Sendable, Equatable, Identifiable {
    public var department: Department
    /// Playable works in the department.
    public var artworkCount: Int
    /// Of those, works with a usable game price.
    public var pricedCount: Int
    public var state: PackState

    public init(department: Department, artworkCount: Int, pricedCount: Int, state: PackState = .bundled) {
        self.department = department
        self.artworkCount = artworkCount
        self.pricedCount = pricedCount
        self.state = state
    }

    public var id: DepartmentID { department.id }
}
