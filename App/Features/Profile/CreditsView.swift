import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// Credits: the dataset disclaimer, data sources and every image credit with its licence.
struct CreditsView: View {
    @State private var credits: CreditsDocument?
    @State private var notice: DatasetNotice?

    var body: some View {
        List {
            Section("About the prices") {
                Text(notice?.disclaimer ?? credits?.disclaimer ?? "")
                    .accessibilityIdentifier("credits.disclaimer")
            }
            if let credits {
                Section("Data sources") {
                    ForEach(credits.dataSources) { source in
                        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                            link(source.name, source.url)
                            Text(source.licence)
                                .artTextStyle(Tokens.Typography.provenance)
                                .foregroundStyle(Tokens.Color.textSecondary)
                        }
                    }
                }
                Section("Images") {
                    ForEach(credits.images) { image in
                        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                            Text(image.title).italic()
                            Text("\(image.artist) · \(image.licence)")
                                .artTextStyle(Tokens.Typography.provenance)
                                .foregroundStyle(Tokens.Color.textSecondary)
                            Text(image.attribution)
                                .artTextStyle(Tokens.Typography.provenance)
                                .foregroundStyle(Tokens.Color.textSecondary)
                            if let landing = image.landingURL { link("Image source", landing) }
                        }
                    }
                }
                if let copy = credits.copy {
                    Section("Writing") { Text(copy) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tokens.Color.bgCanvas)
        .navigationTitle("Credits")
        .task {
            credits = CreditsDocument.load()
            notice = DatasetNotice.load()
        }
    }

    @ViewBuilder
    private func link(_ title: String, _ string: String) -> some View {
        if let url = URL(string: string) {
            Link(title, destination: url)
        } else {
            Text(title)
        }
    }
}
