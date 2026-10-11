import ArtCore
import ArtData
import ArtDesign
import Foundation
import OSLog
import SwiftUI

/// The long-lived objects behind the UI: dependencies plus the observable app-wide models.
final class AppServices {
    let env: AppEnvironment
    let router = Router()
    let settings: SettingsModel
    let profile: ProfileModel
    let day: DayModel

    init(env: AppEnvironment) {
        self.env = env
        settings = SettingsModel(store: env.settingsStore)
        profile = ProfileModel(store: env.profileStore, now: env.now)
        day = DayModel(provider: env.dayProvider)
    }

    /// Loads the profile, starts memory-warning observation and (DEBUG) the dataset validator.
    func start() async {
        await profile.load()
        await env.imageLoader.observeMemoryWarnings()
        if let mode = env.debug.startMode { router.start(mode) }
        if env.debug.seedSwipes { SwipeDebug.seedProfile(profile, dataset: env.dataset) }
        if let route = env.debug.openRoute.flatMap({ ["taste": Route.taste, "collection": .collection][$0] }) {
            router.showProfile()
            router.profilePath = [route]
        }
        runDebugValidation()
    }

    /// DEBUG: validates the bundled dataset in the background and logs the summary.
    private func runDebugValidation() {
        #if DEBUG
        guard !env.launch.uiTesting else { return }
        Task.detached(priority: .background) {
            let report = DatasetValidator.validate(bundle: .main)
            let log = Logger(subsystem: "com.artprice.app", category: "dataset")
            let head = report.summary.split(separator: "\n").prefix(3).joined(separator: " | ")
            log.notice("DatasetValidator: \(head, privacy: .public)")
        }
        #endif
    }
}

extension View {
    /// Injects the environment and the app-wide models.
    func appServices(_ services: AppServices) -> some View {
        self
            .environment(\.app, services.env)
            .environment(services.router)
            .environment(services.settings)
            .environment(services.profile)
            .environment(services.day)
    }
}
