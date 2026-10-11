import Foundation
import Testing

@Suite("Tokens.json")
struct TokensTests {
    @Test func parsesWithRequiredGroups() throws {
        let doc = try TokensDocument()
        for group in ["meta", "color", "font", "space", "radius", "size", "elevation", "motion", "haptic", "gesture"] {
            #expect(doc.node(group) != nil, "missing group \(group)")
        }
        #expect(doc.node("meta.version") as? String != nil)
        for path in ["color.bg.canvas", "color.bg.surface", "color.bg.elevated", "color.text.primary",
                     "color.text.secondary", "color.text.onGilt", "color.accent.gilt", "color.feedback.hit",
                     "color.feedback.miss", "color.line.hairline"] {
            #expect(doc.hex(path, mode: "dark") != nil, "\(path) dark")
            #expect(doc.hex(path, mode: "light") != nil, "\(path) light")
        }
        for name in ["select.commit", "result.hit", "result.miss", "streak.tick", "slider.decade",
                     "slider.minor", "swipe.threshold", "swipe.commit"] {
            let value = (doc.node("haptic.\(name)") as? [String: Any])?["$value"] as? [String: Any]
            #expect(value?["ios"] != nil && value?["android"] is String, "haptic \(name)")
        }
    }

    @Test func plannedPaletteValues() throws {
        // Part C1 values (dark). Light hit/miss were darkened for contrast; see meta.deviations.
        let doc = try TokensDocument()
        #expect(doc.hex("color.bg.canvas", mode: "dark") == "#0E0D0C")
        #expect(doc.hex("color.bg.canvas", mode: "light") == "#F6F2EA")
        #expect(doc.hex("color.accent.gilt", mode: "dark") == "#C9A55C")
        #expect(doc.hex("color.accent.gilt", mode: "light") == "#7A5C14")
    }

    @Test func everyContrastPairMeetsWCAG() throws {
        let doc = try TokensDocument()
        let pairs = try #require(doc.node("meta.contrast_pairs") as? [[String: Any]])
        #expect(pairs.count >= 16)
        for pair in pairs {
            let fg = try #require(pair["fg"] as? String)
            let bg = try #require(pair["bg"] as? String)
            let minimum = try #require(pair["min"] as? Double)
            #expect(minimum >= 4.5)
            let recorded = pair["ratio"] as? [String: Double]
            for mode in ["dark", "light"] {
                let f = try #require(doc.hex(fg, mode: mode), "\(fg) \(mode)")
                let b = try #require(doc.hex(bg, mode: mode), "\(bg) \(mode)")
                let ratio = WCAG.contrast(f, b)
                #expect(ratio >= minimum, "\(fg) on \(bg) [\(mode)] = \(ratio)")
                if let r = recorded?[mode] {
                    #expect(abs(r - ratio) < 0.01, "meta ratio stale for \(fg)/\(bg) \(mode); run gen_tokens.py --update-meta")
                }
            }
        }
    }

    @Test func wcagFormulaReferenceValues() {
        #expect(abs(WCAG.contrast("#000000", "#FFFFFF") - 21) < 0.001)
        #expect(abs(WCAG.contrast("#777777", "#FFFFFF") - 4.48) < 0.01)
    }
}

@Suite("Generated Tokens.swift")
struct TokensSyncTests {
    @Test func generatedFileIsInSyncWithJSON() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("artdesign-tokens-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let out = tmp.appendingPathComponent("Tokens.swift")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", RepoPaths.generator.path, "--tokens", RepoPaths.tokensJSON.path, "--out", out.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let log = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        try #require(process.terminationStatus == 0, "generator failed: \(log)")

        let fresh = try String(contentsOf: out, encoding: .utf8)
        let committed = try String(contentsOf: RepoPaths.generatedSwift, encoding: .utf8)
        #expect(fresh == committed, "Tokens.swift is stale: run python3 Design/gen_tokens.py")
        #expect(committed.hasPrefix("// DO NOT EDIT."))
    }
}
