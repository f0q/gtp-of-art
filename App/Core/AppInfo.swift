import Foundation
/// App-wide names. Decided by the owner on 12 Oct 2026: "GTP of Art" (Guess The Price of Art).
/// Always use the full wordmark; never "GTP" alone (see App Store naming notes in the plan).
enum AppInfo {
    static let wordmark = "GTP of Art"
    static let tagline = "Guess the Price of Art"
    /// Hosted by the owner at the app's domain (required by App Review guideline 5.1.1).
    static let privacyPolicyURL = URL(string: "https://gtp-art.aijam.pro/privacy")!
    static let supportURL = URL(string: "https://gtp-art.aijam.pro/support")!
}
