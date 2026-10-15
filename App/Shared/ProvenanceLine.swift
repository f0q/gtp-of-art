import ArtCore
import ArtData
import ArtDesign
import Foundation
import SwiftUI

/// The reveal's provenance line with an ⓘ button opening `PriceInfoSheet`.
struct ProvenanceLine: View {
    let artwork: Artwork
    let record: PriceRecord
    var text: String? = nil

    @Environment(SettingsModel.self) private var settings
    @State private var showingInfo = false

    var body: some View {
        let line = text ?? PriceCopy.provenance(record, showVenue: settings.settings.showAuctionHouses)
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            Text(line)
                .artTextStyle(Tokens.Typography.provenance)
                .foregroundStyle(Tokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(SpokenPrice.text(line))
            Button { showingInfo = true } label: {
                Image(systemName: "info.circle")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .frame(minWidth: Tokens.Size.minTarget, minHeight: Tokens.Size.minTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("About this price")
            .accessibilityIdentifier("reveal.info")
        }
        .sheet(isPresented: $showingInfo) {
            PriceInfoSheet(artwork: artwork, record: record)
        }
    }
}

/// ⓘ sheet: hammer vs premium, inflation, sources, image credit and licence.
struct PriceInfoSheet: View {
    let artwork: Artwork
    let record: PriceRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        NavigationStack {
            List {
                Section("The price") {
                    let line = PriceCopy.provenance(record, showVenue: settings.settings.showAuctionHouses)
                    Text(line)
                        .accessibilityLabel(SpokenPrice.text(line))
                    Text(PriceCopy.basisExplanation(record))
                    LabeledContent("Original figure", value: PriceCopy.original(record))
                    spokenRow("In US dollars then", "approx. \(PriceCopy.amount(record.usdNominal))")
                    spokenRow("In \(record.adjustRefYear) dollars", PriceFormatter.format(record, basis: .adjusted))
                    Text("Inflation-adjusted values use the US consumer price index and are estimates.")
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
                Section("Sources") {
                    ForEach(record.sourceURLs, id: \.self) { source in
                        if let url = URL(string: source) {
                            Link(url.host() ?? source, destination: url)
                        }
                    }
                }
                Section("Image") {
                    Text(artwork.image.attribution)
                    LabeledContent("Licence", value: artwork.image.licence)
                    if let landing = artwork.image.landingURL, let url = URL(string: landing) {
                        Link("Image source", destination: url)
                    }
                }
                Section {
                    Text("For entertainment and education only. Not an appraisal or valuation.")
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
            }
            .artTextStyle(Tokens.Typography.body)
            .scrollContentBackground(.hidden)
            .background(Tokens.Color.bgCanvas)
            .navigationTitle(artwork.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// A label/value row whose compact price is read out in words.
    private func spokenRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(SpokenPrice.text(value))
    }
}
