import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Root of the window: injects services, applies settings (haptics, appearance) and handles the
/// scene lifecycle (flush the profile on background, recompute the day on activation).
struct AppRoot: View {
    let services: AppServices
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RootView()
            .appServices(services)
            .environment(\.hapticsEnabled, services.env.haptics.isEnabled(services.settings.settings))
            .preferredColorScheme(services.settings.settings.appearance == .dark ? .dark : nil)
            .tint(Tokens.Color.accentGilt)
            .task { await services.start() }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background: Task { await services.profile.flush() }
                case .active: services.day.refresh()
                default: break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                services.day.refresh()
            }
    }
}

/// The hub navigation stack, the session cover and the profile sheet.
struct RootView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .credits: CreditsView()
                    case .taste: TasteProfileView()
                    case .collection: CollectionView()
                    case .collectionArtwork(let id): CollectionDetailView(artworkID: id)
                    }
                }
        }
        .onboardingGate()
        .fullScreenCover(item: $router.session) { route in
            SessionContainer(route: route)
        }
        .sheet(isPresented: $router.isProfilePresented) {
            ProfileSheet()
        }
    }
}

/// Shown if the bundled dataset cannot be read (a broken build, never expected in release).
struct LaunchFailureView: View {
    let message: String

    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle.weight(.medium))
                .foregroundStyle(Tokens.Color.textSecondary)
            Text("The gallery could not open")
                .artTextStyle(Tokens.Typography.displayL)
                .foregroundStyle(Tokens.Color.textPrimary)
            Text(message)
                .artTextStyle(Tokens.Typography.provenance)
                .foregroundStyle(Tokens.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Tokens.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Color.bgCanvas)
    }
}
