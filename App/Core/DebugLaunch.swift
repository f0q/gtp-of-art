import ArtCore
import ArtData
import Foundation

/// DEBUG-only launch hooks used for simulator screenshots:
/// `-startMode <game mode raw value>` opens a session at launch; `-autoAnswer` answers the first
/// round automatically so the reveal can be captured (the daily plays through to its result).
/// `-onboarded` (with `-uiTesting`) starts with the questionnaire already done.
/// Release builds ignore all three.
nonisolated struct DebugLaunch: Sendable, Equatable {
    var startMode: GameMode?
    var autoAnswer: Bool
    var onboarded: Bool
    /// `-debugSwipes`: plays one fixed swipe session into the profile at launch (Taste/Collection shots).
    var seedSwipes = false
    /// `-openRoute taste|collection`: opens the profile sheet on that screen at launch.
    var openRoute: String?

    init(arguments: [String]) {
        #if DEBUG
        seedSwipes = arguments.contains("-debugSwipes")
        if let i = arguments.lastIndex(of: "-openRoute"), i + 1 < arguments.count {
            openRoute = arguments[i + 1]
        }
        if let i = arguments.lastIndex(of: "-startMode"), i + 1 < arguments.count {
            startMode = GameMode(rawValue: arguments[i + 1])
        } else {
            startMode = nil
        }
        autoAnswer = arguments.contains("-autoAnswer")
        onboarded = arguments.contains("-onboarded")
        #else
        startMode = nil
        autoAnswer = false
        onboarded = false
        #endif
    }
}
