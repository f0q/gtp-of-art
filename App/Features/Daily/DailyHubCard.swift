import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// The hub's Daily Challenge card: "Play today" (the hub's one gilt CTA), or today's score with
/// the streak and a practice replay.
struct DailyHubCard: View {
    @Environment(\.app) private var app
    @Environment(DayModel.self) private var day
    @Environment(ProfileModel.self) private var profile
    @Environment(Router.self) private var router
    @State private var buildable = true

    var body: some View {
        let status = DailyService.status(on: day.today, profile: profile.profile)
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack {
                Text("Daily Challenge · Day \(HomeContent.dailyNumber(on: day.today))")
                    .artTextStyle(Tokens.Typography.provenance)
                    .foregroundStyle(Tokens.Color.textSecondary)
                Spacer(minLength: Tokens.Space.s)
                if status.displayedStreak > 0 {
                    Label("\(status.displayedStreak)", systemImage: "photo.artframe")
                        .artTextStyle(Tokens.Typography.label)
                        .foregroundStyle(Tokens.Color.accentGilt)
                        .accessibilityLabel("\(status.displayedStreak) day streak")
                }
            }
            Text(status.isCompleted ? "Done for today" : "Five lots, the same for everyone")
                .artTextStyle(Tokens.Typography.titleArt)
                .foregroundStyle(Tokens.Color.textPrimary)
            if !buildable {
                Text("The gallery is still hanging today's lots. Check back soon.")
                    .artTextStyle(Tokens.Typography.label)
                    .foregroundStyle(Tokens.Color.textSecondary)
            } else if status.isCompleted, let score = status.score {
                Text("Today: \(score)/\(DailyModel.maxTotal). Replays are practice and don't change your score.")
                    .artTextStyle(Tokens.Typography.label)
                    .foregroundStyle(Tokens.Color.textSecondary)
                Button { router.start(.daily) } label: {
                    Text("Practice").frame(maxWidth: .infinity)
                }
                .artButtonStyle(.secondary)
                .accessibilityIdentifier("home.daily.practice")
            } else {
                Text("Pick the price, Which is pricier, Category and Bid in one round of five.")
                    .artTextStyle(Tokens.Typography.label)
                    .foregroundStyle(Tokens.Color.textSecondary)
                Button { router.start(.daily) } label: {
                    Text("Play today").frame(maxWidth: .infinity)
                }
                .artButtonStyle(.prominent)
                .accessibilityIdentifier("home.daily.play")
            }
        }
        .padding(Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Color.bgSurface, in: RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .strokeBorder(Tokens.Color.lineHairline, lineWidth: Tokens.Size.hairline))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.daily")
        .task(id: day.today) { buildable = HomeContent.dailyIsBuildable(on: day.today, dataset: app.dataset) }
    }
}
