@testable import ArtDesign
import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing

@Suite("ImageLoader")
struct ImageLoaderTests {
    func writeTestPNG(width: Int, height: Int) throws -> URL {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                         space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.setFillColor(CGColor(srgbRed: 0.5, green: 0.4, blue: 0.3, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(ctx.makeImage())
        let data = try #require(ShareCardRenderer.encodePNG(image))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("artdesign-\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }

    @Test func decodesDownsampledAndCaches() async throws {
        let url = try writeTestPNG(width: 2000, height: 1000)
        defer { try? FileManager.default.removeItem(at: url) }
        let loader = ImageLoader(costLimit: 8 * 1024 * 1024)
        let request = ImageLoader.Request(url: url, maxPixelSize: 480)
        let image = try await loader.image(for: request)
        #expect(max(image.width, image.height) == 480)
        #expect(image.width == 480 && image.height == 240)
        #expect(await loader.cachedImage(for: request) != nil)
        await loader.removeAll()
        #expect(await loader.cachedImage(for: request) == nil)
    }

    @Test func concurrentRequestsShareResult() async throws {
        let url = try writeTestPNG(width: 800, height: 800)
        defer { try? FileManager.default.removeItem(at: url) }
        let loader = ImageLoader()
        let request = ImageLoader.Request(url: url, points: 100, scale: 3)
        #expect(request.maxPixelSize == 300)
        async let a = loader.image(for: request)
        async let b = loader.image(for: request)
        let (x, y) = try await (a, b)
        #expect(x.width == 300 && y.width == 300)
    }

    @Test func missingFileThrows() async {
        let loader = ImageLoader()
        let url = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).heic")
        await #expect(throws: ImageLoader.LoadError.self) {
            _ = try await loader.image(at: url, maxPixelSize: 100)
        }
    }
}

@MainActor
@Suite("ShareCard + reveal timeline")
struct ShareAndRevealTests {
    @Test func shareCardRendersAt1080x1350() throws {
        let view = ShareCardView(artwork: nil, artworkPixelSize: CGSize(width: 4, height: 5),
                                 artworkPlaceholder: Tokens.Color.bgElevated, title: "Test",
                                 headline: "8/10", marks: [.hit, .close, .miss])
        let image = try #require(ShareCardRenderer.cgImage(view))
        #expect(image.width == 1080 && image.height == 1350)
        let png = try #require(ShareCardRenderer.pngData(view))
        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        let light = try #require(ShareCardRenderer.cgImage(view, colorScheme: .light))
        #expect(light.width == 1080)
    }

    @Test func revealTimelineFollowsTokens() {
        let steps = RevealTimeline.steps(reduceMotion: false)
        #expect(steps.map(\.phase) == [.lock, .dim, .roll, .settle, .provenance, .next])
        #expect(steps.map(\.at) == [0, 0, 0.15, 0.6, 0.65, 0.9])
        #expect(zip(steps, steps.dropFirst()).allSatisfy { $0.at <= $1.at && $0.phase < $1.phase })
    }

    @Test func reduceMotionIsOneShortCrossfade() {
        let steps = RevealTimeline.steps(reduceMotion: true)
        #expect(steps.last?.phase == .next)
        #expect((steps.last?.at ?? 1) <= 0.2)
        #expect(!steps.contains { $0.phase == .roll })
    }

    @Test func driverReachesNext() async throws {
        let driver = HammerRevealDriver()
        driver.start(isHit: true, reduceMotion: true)
        #expect(driver.isLocked)
        try await Task.sleep(for: .milliseconds(450))
        #expect(driver.phase == .next)
        driver.reset()
        #expect(driver.phase == .idle)
    }

    @Test func hapticTokensMapToSensoryFeedback() {
        #expect(Tokens.Haptic.allCases.count == 8)
        #expect(Tokens.Haptic.resultHit.sensoryFeedback == .success)
        #expect(Tokens.Haptic.resultMiss.sensoryFeedback != .error)
        #expect(Tokens.Haptic.swipeThreshold.androidConstant == "GESTURE_THRESHOLD_ACTIVATE")
    }
}
