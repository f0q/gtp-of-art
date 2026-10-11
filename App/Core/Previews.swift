import ArtCore
import ArtData
import ArtDesign
import SwiftUI

#Preview("Home · Dark") {
    NavigationStack { HomeView() }
        .appServices(AppServices(env: .preview))
        .preferredColorScheme(.dark)
}

#Preview("Home · AX5") {
    NavigationStack { HomeView() }
        .appServices(AppServices(env: .preview))
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Pick the price") {
    PickPricePreview()
}

#Preview("Onboarding") {
    let services = AppServices(env: .preview)
    OnboardingView(model: OnboardingModel(dataset: services.env.dataset, profile: services.profile))
        .appServices(services)
}

private struct PickPricePreview: View {
    let services = AppServices(env: .preview)

    var body: some View {
        if let model = try? PickPriceModel(context: .make(dataset: services.env.dataset, profile: services.profile, seed: 7)) {
            PickPriceView(model: model, actions: SessionActions(playAgain: {}, close: {}))
                .appServices(services)
        }
    }
}
