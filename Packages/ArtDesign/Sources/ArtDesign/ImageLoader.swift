import CoreGraphics
import Foundation
import ImageIO
#if canImport(UIKit)
import UIKit
#endif

/// Decodes bundled HEIC/JPEG artworks to display-sized `CGImage`s off the main actor and caches them.
///
/// - Decoding uses `CGImageSourceCreateThumbnailAtIndex` with `maxPixelSize` (points × scale),
///   applies the EXIF transform and decodes immediately, so drawing never decodes on the main thread.
/// - The cache is an `NSCache` limited by decoded byte cost (~60 MB) and is purged on memory warnings
///   (iOS).
/// - Concurrent requests for the same image share one decode.
/// - At most `maxConcurrentDecodes` decodes run at once, each on a dedicated GCD queue, never on the
///   Swift cooperative pool. HEIF decoding blocks inside Apple's video decoder; with an unbounded
///   number of decodes on pool threads, every pool thread parked there and nothing finished
///   (observed with ~10+ simultaneous grid thumbnails on the iOS Simulator).
public actor ImageLoader {
    /// Process-wide loader.
    public static let shared = ImageLoader()

    /// Errors thrown by the loader.
    nonisolated public enum LoadError: Error, Equatable, Sendable {
        /// The file could not be opened as an image source.
        case unreadable(URL)
        /// ImageIO produced no image.
        case decodeFailed(URL)
    }

    /// One image request: a file and the largest pixel dimension needed.
    nonisolated public struct Request: Hashable, Sendable {
        /// File URL of the HEIC/JPEG.
        public let url: URL
        /// Largest pixel dimension to decode (long edge).
        public let maxPixelSize: Int

        /// Creates a request.
        public init(url: URL, maxPixelSize: Int) {
            self.url = url
            self.maxPixelSize = maxPixelSize
        }

        /// Creates a request for a view of `points` long edge at `scale`.
        public init(url: URL, points: CGFloat, scale: CGFloat) {
            self.init(url: url, maxPixelSize: Int((points * scale).rounded(.up)))
        }

        var cacheKey: NSString { "\(maxPixelSize)|\(url.absoluteString)" as NSString }
    }

    /// Default decoded-byte budget for the cache.
    public static let defaultCostLimit = 60 * 1024 * 1024

    /// Default cap on simultaneous decodes. Measured on an M4 Mac (182 bundled HEICs at 480px, best of 5):
    /// 1 → 0.97s, 2 → 0.51s, 3 → 0.36s, 4 → 0.31s, 8 → 0.28s. Gains flatten after 3, so 3 keeps
    /// most of the throughput while leaving the hardware decoder headroom on device.
    public static let defaultMaxConcurrentDecodes = 3

    /// Dedicated queue: blocking ImageIO/HEIF work never occupies Swift cooperative-pool threads.
    private static let decodeQueue = DispatchQueue(label: "ArtDesign.ImageLoader.decode",
                                                   qos: .userInitiated, attributes: .concurrent)

    private let cache = NSCache<NSString, CachedImage>()
    private var inFlight: [Request: Task<CGImage, any Error>] = [:]
    private let maxConcurrentDecodes: Int
    private var runningDecodes = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Highest number of decodes observed running at once (diagnostics and tests).
    public private(set) var maxObservedConcurrentDecodes = 0

    /// Creates a loader.
    /// - Parameters:
    ///   - costLimit: Decoded-byte budget of the cache.
    ///   - maxConcurrentDecodes: Cap on simultaneous decodes (minimum 1).
    public init(costLimit: Int = ImageLoader.defaultCostLimit,
                maxConcurrentDecodes: Int = ImageLoader.defaultMaxConcurrentDecodes) {
        cache.totalCostLimit = costLimit
        cache.name = "ArtDesign.ImageLoader"
        self.maxConcurrentDecodes = max(1, maxConcurrentDecodes)
    }

    /// Returns the decoded image, from cache or by decoding once. Requests for the same
    /// (file, pixel size) share one decode.
    public func image(for request: Request) async throws -> CGImage {
        if let hit = cache.object(forKey: request.cacheKey) { return hit.image }
        if let running = inFlight[request] { return try await running.value }
        let task = Task { try await self.gatedDecode(request) }
        inFlight[request] = task
        defer { inFlight[request] = nil }
        let image = try await task.value
        cache.setObject(CachedImage(image), forKey: request.cacheKey, cost: image.bytesPerRow * image.height)
        return image
    }

    /// Waits for a decode slot, decodes on `decodeQueue`, releases the slot.
    private func gatedDecode(_ request: Request) async throws -> CGImage {
        await acquireSlot()
        defer { releaseSlot() }
        return try await Self.decodeOnQueue(request)
    }

    private func acquireSlot() async {
        if runningDecodes < maxConcurrentDecodes {
            runningDecodes += 1
        } else {
            // The releasing task hands its slot over directly, so `runningDecodes` stays put.
            await withCheckedContinuation { waiters.append($0) }
        }
        maxObservedConcurrentDecodes = max(maxObservedConcurrentDecodes, runningDecodes)
    }

    private func releaseSlot() {
        if waiters.isEmpty {
            runningDecodes -= 1
        } else {
            waiters.removeFirst().resume()
        }
    }

    /// Convenience for `image(for: Request(url:maxPixelSize:))`.
    public func image(at url: URL, maxPixelSize: Int) async throws -> CGImage {
        try await image(for: Request(url: url, maxPixelSize: maxPixelSize))
    }

    /// Cached image without decoding, if present.
    public func cachedImage(for request: Request) -> CGImage? {
        cache.object(forKey: request.cacheKey)?.image
    }

    /// Decodes requests in the background (e.g. the next 3 artworks) so they are ready on reveal.
    public func prefetch(_ requests: [Request]) {
        for request in requests where cache.object(forKey: request.cacheKey) == nil && inFlight[request] == nil {
            Task { _ = try? await self.image(for: request) }
        }
    }

    /// Empties the cache.
    public func removeAll() {
        cache.removeAllObjects()
    }

    /// Purges the cache when iOS posts a memory warning. Call once at launch (no-op on macOS).
    public nonisolated func observeMemoryWarnings() async {
        await MemoryWarningRelay.observe(self)
    }

    /// Runs `decode` on the dedicated queue and resumes the caller with its result.
    nonisolated static func decodeOnQueue(_ request: Request) async throws -> CGImage {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage, any Error>) in
            decodeQueue.async {
                continuation.resume(with: Result { try decode(request) })
            }
        }
    }

    /// Synchronous ImageIO decode. Call only from `decodeQueue` (or tests).
    nonisolated static func decode(_ request: Request) throws -> CGImage {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(request.url as CFURL, sourceOptions) else {
            throw LoadError.unreadable(request.url)
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, request.maxPixelSize),
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            throw LoadError.decodeFailed(request.url)
        }
        return image
    }
}

/// `NSCache` needs a class value.
nonisolated private final class CachedImage: Sendable {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

/// Holds the notification tokens on the main actor so nothing non-Sendable crosses actors.
@MainActor
enum MemoryWarningRelay {
    private static var observers: [ObjectIdentifier: any NSObjectProtocol] = [:]

    static var notificationName: Notification.Name? {
        #if canImport(UIKit)
        UIApplication.didReceiveMemoryWarningNotification
        #else
        nil
        #endif
    }

    static func observe(_ loader: ImageLoader) {
        let id = ObjectIdentifier(loader)
        guard observers[id] == nil, let name = notificationName else { return }
        observers[id] = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
            [weak loader] _ in
            Task { await loader?.removeAll() }
        }
    }
}
