import ArtCore
import Foundation
import Testing

@testable import ArtData

@Suite("Dataset loading")
struct DatasetLoadingTests {
    let dataset = TestSupport.dataset

    @Test func decodesTheRealDataset() {
        #expect(dataset.datasetVersion == dataset.catalog.datasetID)
        #expect(!dataset.datasetVersion.isEmpty)
        #expect(dataset.catalog.artworks.count == 91)
        #expect(dataset.categories.count == 27)
        #expect(dataset.tasteBaseline.features.count > 0)
    }

    @Test func exposesDisclaimerAndRefYear() throws {
        #expect(dataset.refYear == 2025)
        #expect(dataset.disclaimer.hasPrefix("Prices are approximate public figures"))
        #expect(dataset.disclaimer == dataset.catalog.disclaimer)
        var catalog = dataset.catalog
        catalog.disclaimer = nil
        catalog.refYear = nil
        let bare = BundledDataset(
            catalog: catalog, taxonomy: Taxonomy(categories: dataset.categories), tasteBaseline: dataset.tasteBaseline,
            images: dataset.images)
        #expect(bare.disclaimer == DatasetDisclaimer.fallback)
        #expect(bare.refYear == 2025)
    }

    @Test func splitsPricedAndUnpriced() {
        #expect(dataset.pricedArtworks.count == 62)
        #expect(dataset.unpricedArtworks.count == 29)
        #expect(dataset.pricedArtworks.count + dataset.unpricedArtworks.count == dataset.pool.artworks.count)
        #expect(dataset.pricedArtworks.allSatisfy { $0.gamePrice != nil })
        #expect(dataset.unpricedArtworks.allSatisfy { $0.gamePrice == nil })
    }

    @Test func poolIsSortedAndIndexed() throws {
        let ids = dataset.pool.artworks.map(\.id)
        #expect(ids == ids.sorted())
        let first = try #require(dataset.pool.artworks.first)
        #expect(dataset.artwork(first.id) == first)
        #expect(dataset.category(first.category)?.id == first.category)
    }

    @Test func locatesImagesAndPlaceholders() throws {
        let work = try #require(dataset.pool.artworks.first)
        let small = try #require(dataset.images.url(for: work, rendition: .small))
        let large = try #require(dataset.images.url(for: work, rendition: .large))
        #expect(small.lastPathComponent == work.image.sm?.file)
        #expect(large.lastPathComponent == work.image.lg?.file)
        #expect(FileManager.default.fileExists(atPath: small.path))
        #expect(FileManager.default.fileExists(atPath: large.path))
        let placeholder = dataset.images.placeholder(for: work, rendition: .large)
        #expect(placeholder.pixelSize == PixelSize(width: work.image.lg!.w, height: work.image.lg!.h))
        #expect(placeholder.color != nil)
        #expect(placeholder.focus == work.image.focus)
    }

    @Test func parsesPlaceholderColours() {
        #expect(PlaceholderColor(hex: "#C5c0B8") == PlaceholderColor(red: 197, green: 192, blue: 184))
        #expect(PlaceholderColor(hex: "C5C0B8") == nil)
        #expect(PlaceholderColor(hex: "#C5C0BZ") == nil)
    }

    @Test func sniffsImageMagicBytes() {
        #expect(ImageFileFormat.sniff(Data([0xFF, 0xD8, 0xFF, 0xE0])) == .jpeg)
        let heic = Data([0, 0, 0, 0x24] + Array("ftypheic".utf8))
        #expect(ImageFileFormat.sniff(heic) == .heic)
        #expect(ImageFileFormat.sniff(Data([0, 0, 0, 0x24] + Array("ftypisom".utf8))) == nil)
        #expect(ImageFileFormat.sniff(Data([0x89, 0x50, 0x4E, 0x47])) == nil)
    }

    @Test func missingDirectoryThrows() {
        #expect(throws: DatasetLoadError.self) {
            _ = try BundledDataset(resourcesDirectory: URL(fileURLWithPath: "/nonexistent-artdata"))
        }
    }
}

@Suite("Departments and onboarding catalog")
struct DepartmentLoadingTests {
    let dataset = TestSupport.dataset

    @Test func loadsDepartmentsIntoPool() {
        #expect(dataset.departments.map(\.id) == [
            .asianArt, .impressionistModern, .nineteenthCentury, .oldMasters, .printsPhotographs,
        ])
        #expect(dataset.pool.artworks.allSatisfy { dataset.department(of: $0.id) != nil })
    }

    @Test func contentPacksCoverThePool() {
        let packs = dataset.contentPacks
        #expect(packs.count == 5)
        #expect(packs.allSatisfy { $0.state == .bundled && $0.artworkCount > 0 })
        #expect(packs.map(\.artworkCount).reduce(0, +) == dataset.pool.artworks.count)
        #expect(packs.map(\.pricedCount).reduce(0, +) == dataset.pricedArtworks.count)
        #expect(packs.map(\.id) == dataset.departments.map(\.id))
    }

    @Test func loadsOnboardingCatalog() throws {
        let onboarding = dataset.onboarding
        #expect(onboarding.schemaVersion == 1)
        #expect(onboarding.choices(step: 1).compactMap(\.era) == [.classic, .modern])
        #expect(Set(onboarding.choices(step: 2).compactMap(\.department)) == Set(dataset.departments.map(\.id)))
        #expect(Set(onboarding.choices(step: 3).compactMap(\.subject)) == Set(OnboardingAnswers.Subject.allCases))
        #expect(Set(onboarding.choices(step: 4).compactMap(\.mood)) == Set(OnboardingAnswers.Mood.allCases))
        let avantGarde = try #require(onboarding.choice("impressionist_modern:avant_garde"))
        #expect(avantGarde.department == .impressionistModern && avantGarde.qualifier == "avant_garde")
        for choice in onboarding.choices {
            for ex in choice.exemplars { #expect(dataset.artwork(ex.artworkID) != nil, "\(ex.artworkID)") }
        }
    }

    @Test func onboardingIsOptional() throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        for file in [DatasetFiles.dataset, DatasetFiles.taxonomy, DatasetFiles.tasteBaseline] {
            try FileManager.default.copyItem(
                at: TestSupport.resourcesDirectory.appendingPathComponent(file), to: dir.appendingPathComponent(file))
        }
        #expect(try BundledDataset(resourcesDirectory: dir).onboarding == .empty)
    }
}
