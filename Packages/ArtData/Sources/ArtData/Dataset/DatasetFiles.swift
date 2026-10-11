import Foundation

/// File names and folder layout of the bundled dataset.
///
/// In the app the three JSON files sit at the bundle's resource root and the images in the
/// `Artworks/` folder reference. Tests point at the repository's `Resources/` directory, which has
/// the same layout.
public enum DatasetFiles {
    public static let dataset = "dataset.json"
    public static let taxonomy = "taxonomy.json"
    public static let tasteBaseline = "taste_baseline.json"
    public static let onboarding = "onboarding.json"
    public static let artworksFolder = "Artworks"

    /// The images folder inside a resources directory.
    public static func artworksDirectory(in resources: URL) -> URL {
        resources.appendingPathComponent(artworksFolder, isDirectory: true)
    }
}

/// Why a dataset could not be loaded.
public enum DatasetLoadError: Error, Sendable, CustomStringConvertible {
    /// The bundle has no resource directory.
    case missingResourceDirectory
    /// A file could not be read.
    case unreadable(file: String, underlying: String)
    /// A file could not be decoded.
    case undecodable(file: String, underlying: String)

    public var description: String {
        switch self {
        case .missingResourceDirectory: "bundle has no resource directory"
        case .unreadable(let file, let underlying): "cannot read \(file): \(underlying)"
        case .undecodable(let file, let underlying): "cannot decode \(file): \(underlying)"
        }
    }
}
