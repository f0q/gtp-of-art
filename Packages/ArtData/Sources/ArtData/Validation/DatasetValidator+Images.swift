import ArtCore
import Foundation

extension DatasetValidator {
    /// Both renditions listed with positive sizes; files exist, are HEIC/JPEG by magic bytes and
    /// match the recorded byte count; placeholder colour and focus are well-formed; no orphan files.
    static func checkImages(
        _ works: [Artwork], locator: ImageLocator, checkFiles: Bool, report: inout DatasetValidationReport
    ) {
        var referenced = Set<String>()
        for work in works {
            let image = work.image
            if PlaceholderColor(hex: image.dominantHex) == nil {
                report.add(.error, "dominant_hex_invalid", "dominant_hex \(image.dominantHex) is not #RRGGBB", work.id)
            }
            if !(0...1000).contains(image.focus.x) || !(0...1000).contains(image.focus.y) {
                report.add(.error, "focus_out_of_range", "focus (\(image.focus.x), \(image.focus.y)) not in 0…1000", work.id)
            }
            if image.altText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                report.add(.warning, "alt_text_missing", "image has no alt text", work.id)
            }
            if image.attribution.isEmpty || image.licence.isEmpty {
                report.add(.error, "image_rights_missing", "image needs licence and attribution", work.id)
            }
            for rendition in ImageRendition.allCases {
                guard let file = locator.file(for: work, rendition: rendition) else {
                    report.add(.warning, "image_rendition_missing", "no \(rendition.rawValue) rendition listed", work.id)
                    continue
                }
                referenced.insert(file.file)
                if file.w <= 0 || file.h <= 0 {
                    report.add(.error, "image_size_invalid", "\(file.file) has size \(file.w)×\(file.h)", work.id)
                }
                if checkFiles { checkImageFile(file, locator: locator, work: work.id, report: &report) }
            }
            if image.sm == nil && image.lg == nil {
                report.add(.error, "image_missing", "artwork lists no image file", work.id)
            }
        }
        guard checkFiles else { return }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: locator.directory.path)) ?? []
        let orphans = names.filter { name in
            let lower = name.lowercased()
            return (lower.hasSuffix(".heic") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg"))
                && !referenced.contains(name)
        }.sorted()
        if !orphans.isEmpty {
            report.add(.warning, "image_orphans",
                "\(orphans.count) image files are not referenced: \(orphans.prefix(5).joined(separator: ", "))")
        }
    }

    static func checkImageFile(_ file: ImageFile, locator: ImageLocator, work: ArtworkID,
        report: inout DatasetValidationReport)
    {
        let url = locator.url(forFileNamed: file.file)
        report.imageFilesChecked += 1
        let format: ImageFileFormat?
        do {
            format = try ImageFileFormat.sniff(fileAt: url)
        } catch {
            report.add(.error, "image_file_missing", "\(file.file) is missing or unreadable", work)
            return
        }
        if format == nil {
            report.add(.error, "image_file_format", "\(file.file) is neither HEIC nor JPEG (magic bytes)", work)
        }
        if let expected = file.bytes,
            let actual = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int,
            actual != expected
        {
            report.add(.warning, "image_bytes_mismatch", "\(file.file) is \(actual) bytes, dataset says \(expected)", work)
        }
    }
}
