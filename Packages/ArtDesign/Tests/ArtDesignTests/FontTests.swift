@testable import ArtDesign
import CoreText
import Foundation
import Testing

@MainActor
@Suite("Fraunces font")
struct FontTests {
    @Test func bundledFilesExistAndMatchDesignSource() throws {
        for file in Tokens.Typography.displayFontFiles {
            let bundled = try #require(ArtFonts.url(forFile: file), "missing \(file) in bundle")
            let source = RepoPaths.designFonts.appendingPathComponent(file)
            #expect(try Data(contentsOf: bundled) == Data(contentsOf: source), "\(file) differs from Design/Fonts")
        }
        let ofl = try String(contentsOf: RepoPaths.designFonts.appendingPathComponent("OFL.txt"), encoding: .utf8)
        #expect(ofl.contains("SIL OPEN FONT LICENSE Version 1.1"))
        let bundledOFL = try String(contentsOf: RepoPaths.packageFonts.appendingPathComponent("OFL.txt"), encoding: .utf8)
        #expect(bundledOFL == ofl)
    }

    @Test func registersAndResolvesPostScriptNames() {
        let statuses = ArtFonts.register()
        #expect(statuses.count == 2)
        for status in statuses.values {
            #expect(status == .registered || status == .alreadyRegistered, "\(status)")
        }
        #expect(ArtFonts.isAvailable)
        let font = CTFontCreateWithName(Tokens.Typography.displayPostScriptName as CFString, 20, nil)
        #expect((CTFontCopyFamilyName(font) as String) == "Fraunces")
        ArtFonts.register() // idempotent
    }

    @Test func variationAxesArePinned() throws {
        ArtFonts.register()
        let style = Tokens.Typography.displayXL
        let font = try #require(ArtFont.makeVariableCTFont(name: Tokens.Typography.displayPostScriptName,
                                                           style: style, size: style.size))
        let variation = try #require(CTFontCopyVariation(font) as? [NSNumber: NSNumber])
        #expect(variation[NSNumber(value: FontAxis.weight)]?.doubleValue == 500)
        #expect(variation[NSNumber(value: FontAxis.softness)]?.doubleValue == 50)
        #expect(variation[NSNumber(value: FontAxis.opticalSize)]?.doubleValue == 72)
        #expect(CTFontGetSize(font) == 40)
    }

    @Test func typeScaleMatchesPlan() {
        #expect(Tokens.Typography.displayXL.size == 40 && Tokens.Typography.displayXL.weight == 500)
        #expect(Tokens.Typography.displayXL.relativeTo == .largeTitle)
        #expect(Tokens.Typography.titleArt.italic && Tokens.Typography.titleArt.size == 22)
        #expect(Tokens.Typography.priceHero.size == 48 && Tokens.Typography.priceHero.monospacedDigit)
        #expect(Tokens.Typography.provenance.smallCaps && Tokens.Typography.provenance.relativeTo == .footnote)
    }
}
