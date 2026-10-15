import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Placeholder Profile: per-mode stats, Settings toggles, Credits.
struct ProfileSheet: View {
    @Environment(Router.self) private var router
    @Environment(SettingsModel.self) private var settings
    @Environment(ProfileModel.self) private var profile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var router = router
        @Bindable var settings = settings
        NavigationStack(path: $router.profilePath) {
            List {
                Section("Your play") {
                    ForEach(HomeContent.tiles.filter(\.isAvailable)) { tile in
                        LabeledContent(tile.title, value: statsLine(profile.stats(tile.mode), mode: tile.mode))
                    }
                }
                Section("Your gallery") {
                    NavigationLink(value: Route.taste) {
                        Label("Your taste", systemImage: "paintpalette")
                    }
                    .accessibilityIdentifier("profile.taste")
                    NavigationLink(value: Route.collection) {
                        Label("Collection", systemImage: "square.grid.3x3")
                    }
                    .accessibilityIdentifier("profile.collection")
                }
                Section("Settings") {
                    Toggle("Haptics", isOn: $settings.settings.haptics)
                        .accessibilityIdentifier("settings.haptics")
                    Toggle("Sound", isOn: $settings.settings.sound)
                    Picker("Appearance", selection: $settings.settings.appearance) {
                        Text("Follow system").tag(AppearancePreference.system)
                        Text("Always dark").tag(AppearancePreference.dark)
                    }
                    Toggle("Show auction houses", isOn: $settings.settings.showAuctionHouses)
                    Picker("Difficulty", selection: $settings.settings.difficulty) {
                        Text("From your answers").tag(Difficulty?.none)
                        Text("Easy").tag(Difficulty?.some(.easy))
                        Text("Medium").tag(Difficulty?.some(.medium))
                        Text("Hard").tag(Difficulty?.some(.hard))
                    }
                    .accessibilityIdentifier("settings.difficulty")
                    Button("Redo questionnaire") {
                        dismiss()
                        profile.resetOnboarding()
                    }
                    .accessibilityIdentifier("settings.redoOnboarding")
                }
                Section {
                    NavigationLink("Credits and sources", value: Route.credits)
                        .accessibilityIdentifier("profile.credits")
                    Link(destination: AppInfo.privacyPolicyURL) {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                    .accessibilityIdentifier("profile.privacy")
                    Link(destination: AppInfo.supportURL) {
                        Label("Support", systemImage: "questionmark.circle")
                    }
                    .accessibilityIdentifier("profile.support")
                } footer: {
                    Text("Prices are approximate public figures, for entertainment and education only.")
                }
            }
            .tint(Tokens.Color.accentGilt)
            .scrollContentBackground(.hidden)
            .background(Tokens.Color.bgCanvas)
            .navigationTitle("Profile")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .credits: CreditsView()
                case .taste: TasteProfileView()
                case .collection: CollectionView()
                case .collectionArtwork(let id): CollectionDetailView(artworkID: id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("profile.done")
                }
            }
        }
    }

    private func statsLine(_ stats: ModeStats, mode: GameMode) -> String {
        guard stats.roundsPlayed > 0 else { return "Not played yet" }
        if mode == .higherLower { return "Best streak \(stats.bestStreak)" }
        return "\(stats.roundsCorrect)/\(stats.roundsPlayed) · best \(stats.bestSessionPoints)"
    }
}
