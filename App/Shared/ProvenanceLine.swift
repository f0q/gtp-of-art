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
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            Text(text ?? PriceCopy.provenance(record, showVenue: settings.settings.showAuctionHouses))
                .artTextStyle(Tokens.Typography.provenance)
                .foregroundStyle(Tokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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
                    Text(PriceCopy.provenance(record, showVenue: settings.settings.showAuctionHouses))
                    Text(PriceCopy.basisExplanation(record))
                    LabeledContent("Original figure", value: PriceCopy.original(record))
                    LabeledContent("In US dollars then", value: "approx. \(PriceCopy.amount(record.usdNominal))")
                    LabeledContent(
                        "In \(record.adjustRefYear) dollars",
                        value: PriceFormatter.format(record, basis: .adjusted))
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
}
