import ArtCore
import ArtData
import ArtDesign
import SwiftUI

/// "Your taste" (from the profile sheet): archetype, pigment bars, rarity, what drives it, swipe
/// count and a "Swipe more" CTA.
struct TasteProfileView: View {
    @Environment(\.app) private var app
    @Environment(ProfileModel.self) private var profile
    @Environment(Router.self) private var router
    @State private var liked: [Artwork] = []

    /// Optional injected liked works (snapshots); otherwise read from the round history.
    var likedOverride: [Artwork]?

    private var taste: TasteProfile { profile.profile.taste }
    private var reading: TasteReading {
        TasteReading(profile: taste, dataset: app.dataset, liked: likedOverride ?? liked)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.Space.xl) {
                if taste.swipeCount == 0 {
                    empty
                } else {
                    let reading = reading
                    ArchetypeHeader(reading: reading)
                    PigmentBars(reading: reading)
                    RarityBlock(reading: reading)
                    explanations(reading)
                    Text(swipeLine)
                        .artTextStyle(Tokens.Typography.provenance)
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .accessibilityIdentifier("taste.swipeCount")
                }
            }
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.xl)
            .frame(maxWidth: .infinity)
        }
        .background(Tokens.Color.bgCanvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            SessionPrimaryButton(title: taste.swipeCount == 0 ? "Start swiping" : "Swipe more",
                                 identifier: "taste.swipeMore", action: swipeMore)
                .padding(.horizontal, Tokens.Space.l)
                .padding(.vertical, Tokens.Space.s)
                .background(Tokens.Color.bgCanvas.ignoresSafeArea(edges: .bottom))
        }
        .navigationTitle("Your taste")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadLiked() }
    }

    private var swipeLine: String {
        "Based on \(taste.swipeCount) swipe\(taste.swipeCount == 1 ? "" : "s"), \(taste.likeCount) kept. Rarity is estimated."
    }

    private var empty: some View {
        VStack(spacing: Tokens.Space.m) {
            Image(systemName: "rectangle.stack")
                .font(.largeTitle.weight(.medium))
                .foregroundStyle(Tokens.Color.textSecondary)
            Text("Your taste is still a blank wall")
                .artTextStyle(Tokens.Typography.displayL)
                .foregroundStyle(Tokens.Color.textPrimary)
            Text("Keep or pass on 20 works and we will name your taste. No prices, no wrong answers.")
                .artTextStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Color.textSecondary)
        }
        .multilineTextAlignment(.center)
        .accessibilityIdentifier("taste.empty")
    }

    @ViewBuilder
    private func explanations(_ reading: TasteReading) -> some View {
        if reading.leaning != nil || reading.avoiding != nil {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                if let leaning = reading.leaning {
                    Label(leaning, systemImage: "heart")
                }
                if let avoiding = reading.avoiding {
                    Label(avoiding, systemImage: "xmark")
                }
            }
            .artTextStyle(Tokens.Typography.body)
            .foregroundStyle(Tokens.Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("taste.explanations")
        }
    }

    private func swipeMore() {
        router.isProfilePresented = false
        Task {
            try? await Task.sleep(for: .seconds(Tokens.Motion.Duration.reveal))
            router.start(.swipe)
        }
    }

    private func loadLiked() async {
        guard likedOverride == nil else { return }
        let log = await profile.roundLog()
        liked = log.records.compactMap { record in
            guard case .swipe(let round) = record.round, record.outcome.liked == true else { return nil }
            return app.dataset.artwork(round.artwork)
        }
    }
}
