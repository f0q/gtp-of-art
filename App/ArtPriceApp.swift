import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// App entry point. Builds the live services once; a dataset that cannot load shows a failure screen.
@main
struct ArtPriceApp: App {
    @State private var boot = AppBoot()

    var body: some Scene {
        WindowGroup {
            switch boot.result {
            case .success(let services):
                AppRoot(services: services)
            case .failure(let error):
                LaunchFailureView(message: String(describing: error))
            }
        }
    }
}

/// Owns the one-time construction of `AppServices`.
@Observable
final class AppBoot {
    let result: Result<AppServices, any Error>

    init() {
        do {
            result = .success(AppServices(env: try AppEnvironment.live()))
        } catch {
            result = .failure(error)
        }
    }
}
