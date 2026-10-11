import SwiftUI
#if canImport(UIKit)
import UIKit
/// The platform's native image type (`UIImage` on iOS, `NSImage` on macOS).
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
/// The platform's native image type (`UIImage` on iOS, `NSImage` on macOS).
public typealias PlatformImage = NSImage
#endif

nonisolated extension CGImage {
    /// Pixel size of the image.
    public var artPixelSize: CGSize { CGSize(width: width, height: height) }

    /// Wraps the image in the platform image type at the given scale.
    public func artPlatformImage(scale: CGFloat = 1) -> PlatformImage {
        #if canImport(UIKit)
        UIImage(cgImage: self, scale: scale, orientation: .up)
        #else
        NSImage(cgImage: self, size: CGSize(width: CGFloat(width) / scale, height: CGFloat(height) / scale))
        #endif
    }
}
