import ArtCore
import ArtData
import Foundation

extension SwipeDebug {
    /// DEBUG screenshots (`-debugSwipes`): plays one fixed-seed swipe session with the fixed
    /// like/pass pattern straight into the profile, so Taste and Collection have content.
    @MainActor static func seedProfile(_ profile: ProfileModel, dataset: any DatasetProviding) {
        guard let model = try? SwipeModel(
            dataset: dataset, profile: profile, seed: fnv1a64("artprice|debug|swipes"), prior: profile.profile.prior)
        else { return }
        var n = 0
        while !model.isFinished, model.swipe(liked: likes(n)) { n += 1 }
    }
}
