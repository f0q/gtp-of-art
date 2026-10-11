@testable import ArtDesign
import CoreGraphics
import Foundation
import Testing

/// Regression for the HEIF decoder deadlock: many concurrent HEIC decodes used to park every
/// cooperative-pool thread inside Apple's decoder, so no thumbnail ever finished.
@Suite("ImageLoader stress (real HEICs)")
struct ImageLoaderStressTests {
    static let artworks = RepoPaths.repoRoot.appendingPathComponent("Resources/Artworks")

    static func heicFiles(limit: Int) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: artworks, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension.lowercased() == "heic" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .prefix(limit).map { $0 }
    }

    enum StressError: Error { case timedOut(Int) }

    @Test(.timeLimit(.minutes(1)))
    func sixtyConcurrentThumbnailsComplete() async throws {
        let files = Self.heicFiles(limit: 60)
        try #require(files.count >= 30, "need real HEICs in Resources/Artworks")
        // 60 requests: every file once, plus duplicates to exercise in-flight dedupe.
        let requests = (0..<60).map { ImageLoader.Request(url: files[$0 % files.count], maxPixelSize: 240) }
        let loader = ImageLoader()
        let start = ContinuousClock.now

        let decoded = try await withThrowingTaskGroup(of: Int.self) { group in
            for request in requests {
                group.addTask {
                    let image = try await loader.image(for: request)
                    return max(image.width, image.height)
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw StressError.timedOut(-1)
            }
            var sizes: [Int] = []
            for try await size in group {
                sizes.append(size)
                if sizes.count == requests.count { group.cancelAll() ; break }
            }
            return sizes
        }
        #expect(decoded.count == 60)
        #expect(decoded.allSatisfy { $0 <= 240 && $0 > 0 })
        #expect(await loader.maxObservedConcurrentDecodes <= ImageLoader.defaultMaxConcurrentDecodes)
        print("60 HEIC thumbnails in \(ContinuousClock.now - start)")
    }
}
