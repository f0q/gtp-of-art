import Foundation

/// Image container formats the app can decode, identified by magic bytes.
public enum ImageFileFormat: String, Sendable, Equatable {
    case heic
    case jpeg

    /// HEIF `ftyp` major brands accepted as HEIC/HEIF stills.
    static let heifBrands: Set<String> = ["heic", "heix", "heim", "heis", "mif1", "msf1", "hevc", "hevx"]

    /// Identifies the format from the first bytes of a file:
    /// JPEG = `FF D8 FF`; HEIC = ISO-BMFF box `....ftyp` with a HEIF major brand at bytes 8…11.
    public static func sniff(_ header: Data) -> ImageFileFormat? {
        let b = [UInt8](header.prefix(12))
        if b.count >= 3, b[0] == 0xFF, b[1] == 0xD8, b[2] == 0xFF { return .jpeg }
        guard b.count >= 12, Array(b[4..<8]) == Array("ftyp".utf8) else { return nil }
        let brand = String(decoding: b[8..<12], as: UTF8.self)
        return heifBrands.contains(brand) ? .heic : nil
    }

    /// Reads the first 12 bytes of a file and sniffs them. Throws if the file cannot be opened.
    public static func sniff(fileAt url: URL) throws -> ImageFileFormat? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: 12) ?? Data()
        return sniff(header)
    }
}
