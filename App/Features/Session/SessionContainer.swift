import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Callbacks a mode screen uses to leave or restart.
struct SessionActions {
    var playAgain: () -> Void
    var close: () -> Void
}

/// Hosts one play session in the full-screen cover. "Play again" bumps `attempt`, which rebuilds
/// the mode screen (and its model) with a fresh seed.
struct SessionContainer: View {
    let route: SessionRoute
    @Environment(Router.self) private var router
    @State private var attempt = 0

    var body: some View {
        content
            .id(attempt)
            .background(Tokens.Color.bgCanvas.ignoresSafeArea())
            .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var content: some View {
        let actions = SessionActions(playAgain: { attempt += 1 }, close: { router.endSession() })
        switch route.mode {
        case .pickPrice:
            SessionScreen(mode: .pickPrice, attempt: attempt, actions: actions, make: PickPriceModel.init(context:)) {
                PickPriceView(model: $0, actions: actions)
            }
        case .bid:
            SessionScreen(mode: .bid, attempt: attempt, actions: actions, make: BidModel.init(context:)) {
                BidView(model: $0, actions: actions)
            }
        case .higherLower:
            SessionScreen(mode: .higherLower, attempt: attempt, actions: actions, make: PricierModel.init(context:)) {
                PricierView(model: $0, actions: actions)
            }
        case .category:
            SessionScreen(mode: .category, attempt: attempt, actions: actions, make: CategoryModel.init(context:)) {
                CategoryView(model: $0, actions: actions)
            }
        case .daily:
            SessionScreen(mode: .daily, attempt: attempt, actions: actions, make: DailyModel.init(context:)) {
                DailyView(model: $0, actions: actions)
            }
        case .swipe:
            SessionScreen(mode: .swipe, attempt: attempt, actions: actions, make: SwipeModel.init(context:)) {
                SwipeView(model: $0, actions: actions)
            }
        }
    }
}

/// Creates a mode model once (seeded from the app's seed policy) and shows its view, or an error.
struct SessionScreen<Model: AnyObject, Content: View>: View {
    typealias Make = (SessionContext) throws -> Model

    let mode: GameMode
    let attempt: Int
    let actions: SessionActions
    let make: Make
    @ViewBuilder let content: (Model) -> Content

    @Environment(\.app) private var app
    @Environment(ProfileModel.self) private var profile
    @Environment(SettingsModel.self) private var settings
    @State private var model: Model?
    @State private var failure: String?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else if let failure {
                SessionUnavailableView(message: failure, actions: actions)
            } else {
                Color.clear
            }
        }
        .onAppear(perform: build)
    }

    private func build() {
        guard model == nil, failure == nil else { return }
        do {
            let context = SessionContext(
                dataset: app.dataset, profile: profile, seed: app.seeds.seed(for: mode, attempt: attempt),
                difficulty: settings.difficulty(prior: profile.profile.prior), prior: profile.profile.prior,
                dayProvider: app.dayProvider)
            model = try make(context)
        } catch {
            failure = "Could not deal this session (\(error))."
        }
    }
}

/// Fallback for modes that are not playable yet or failed to generate.
struct SessionUnavailableView: View {
    let message: String
    let actions: SessionActions

    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            Image(systemName: "hourglass")
                .font(.largeTitle.weight(.medium))
                .foregroundStyle(Tokens.Color.textSecondary)
            Text(message)
                .artTextStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textPrimary)
                .multilineTextAlignment(.center)
            Button("Back to the hub", action: actions.close)
                .artButtonStyle(.secondary)
        }
        .padding(Tokens.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
