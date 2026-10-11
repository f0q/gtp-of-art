import ArtCore
import ArtData
import Foundation
import Observation

/// Pushed destinations of the root and profile navigation stacks.
enum Route: Hashable {
    case credits
    /// "Your taste" (Features/Taste).
    case taste
    /// "Works you've seen" (Features/Collection).
    case collection
    /// One work from the collection.
    case collectionArtwork(ArtworkID)
}

/// A play session presented in a full-screen cover.
struct SessionRoute: Identifiable, Hashable {
    let id = UUID()
    let mode: GameMode
}

/// Navigation state: root `NavigationStack` path, the active session cover and the profile sheet.
@Observable
final class Router {
    var path: [Route] = []
    var session: SessionRoute?
    var isProfilePresented = false
    var profilePath: [Route] = []

    func start(_ mode: GameMode) {
        session = SessionRoute(mode: mode)
    }

    func endSession() {
        session = nil
    }

    func showProfile() {
        profilePath = []
        isProfilePresented = true
    }
}
