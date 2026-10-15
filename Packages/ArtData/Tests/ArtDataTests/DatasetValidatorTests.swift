import ArtCore
import Foundation
import Testing

@testable import ArtData

@Suite("Dataset validator")
struct DatasetValidatorTests {
    /// The full validator on the shipping data (daily proof from 2026-10-12). Prints the summary
    /// and requires zero errors; warnings are allowed.
    @Test func realDatasetFullValidation() {
        let report = DatasetValidator.validate(
            resourcesDirectory: TestSupport.resourcesDirectory,
            options: ValidationOptions(dailyStart: DayKey(year: 2026, month: 10, day: 12)))
        print("===== DatasetValidator summary =====\n" + report.summary + "\n====================================")
        #expect(report.artworkCount == 417)
        #expect(report.pricedCount == 300)
        #expect(report.imageFilesChecked == 834)
        #expect(report.daily?.daysChecked == 730)
        #expect(report.daily?.failures.isEmpty == true)
        #expect(report.roundProbes.count == RoundKind.allCases.count * Difficulty.allCases.count)
        #expect(report.sessionProbes.allSatisfy { $0.successes == $0.attempts })
        #expect(report.errors.isEmpty, "validation errors: \(report.errors)")
    }

    @Test func staticChecksCatchBrokenData() throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fm = FileManager.default
        for file in [DatasetFiles.taxonomy, DatasetFiles.tasteBaseline] {
            try fm.copyItem(at: TestSupport.resourcesDirectory.appendingPathComponent(file), to: dir.appendingPathComponent(file))
        }
        // Take two works, break them, write them as a tiny dataset with an empty Artworks folder.
        let data = try Data(contentsOf: TestSupport.resourcesDirectory.appendingPathComponent(DatasetFiles.dataset))
        var top = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var works = try #require(top["artworks"] as? [[String: Any]])
        let priced = try #require(works.first { $0["game_price_id"] is String })
        var a = priced
        var b = priced  // duplicate id
        var prices = try #require(a["prices"] as? [[String: Any]])
        prices[0]["log10_usd_nominal_milli"] = (prices[0]["log10_usd_nominal_milli"] as! Int) + 3
        a["prices"] = prices
        a["category_id"] = "no_such_category"
        b["game_price_id"] = "missing-price"
        var c = works[0]
        c["id"] = "broken"
        c.removeValue(forKey: "title")
        works = [a, b, c]
        top["artworks"] = works
        try JSONSerialization.data(withJSONObject: top).write(to: dir.appendingPathComponent(DatasetFiles.dataset))
        try fm.createDirectory(at: DatasetFiles.artworksDirectory(in: dir), withIntermediateDirectories: true)

        let report = DatasetValidator.validate(
            resourcesDirectory: dir, options: ValidationOptions(runGenerationProbes: false))
        let codes = Set(report.errors.map(\.code))
        #expect(codes.contains("log10_mismatch"))
        #expect(codes.contains("unknown_category"))
        #expect(codes.contains("duplicate_artwork_id"))
        #expect(codes.contains("game_price_unresolved"))
        #expect(codes.contains("artwork_undecodable"))
        #expect(codes.contains("image_file_missing"))
        #expect(!report.isValid)
    }
}

@Suite("Quiz threshold what-if")
struct QuizThresholdWhatIfTests {
    /// Diagnostic for the data lead: with the v0 data, which `min_quiz_items` makes the category
    /// quiz and the daily challenge generate? Prints a table; asserts only that lowering the
    /// threshold far enough does fix it (so the test datasets used elsewhere are sound).
    @Test func dailyAndCategoryByThreshold() {
        var lines = ["min_quiz_items | quiz cats | daily ok/730 | category sessions ok/50"]
        var bestDaily = 0
        for k in [1, 2, 3, 4, 5, 6, 8] {
            let data = TestSupport.dataset(minQuizItems: k)
            let daily = DailyValidator.check(
                data.pool, from: DayKey(year: 2026, month: 10, day: 11), days: 730,
                datasetVersion: data.datasetVersion)
            let okDays = 730 - Set(daily.failures.map(\.day)).count
            bestDaily = max(bestDaily, okDays)
            let sessions = GeneratorProbe.probeSessions(mode: .category, pool: data.pool, attempts: 50)
            lines.append("\(k) | \(data.pool.quizCategoryIDs.count) | \(okDays) | \(sessions.successes)")
        }
        print("===== Quiz threshold what-if =====\n" + lines.joined(separator: "\n"))
        #expect(bestDaily == 730)
    }
}

@Suite("Validator: departments and onboarding")
struct DepartmentValidationTests {
    @Test func catchesDepartmentAndOnboardingProblems() throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let src = TestSupport.resourcesDirectory
        try FileManager.default.copyItem(
            at: src.appendingPathComponent(DatasetFiles.tasteBaseline), to: dir.appendingPathComponent(DatasetFiles.tasteBaseline))
        // Dataset: realism works lose their explicit department_id.
        var dataset = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: src.appendingPathComponent(DatasetFiles.dataset)))
                as? [String: Any])
        dataset["artworks"] = (dataset["artworks"] as! [[String: Any]]).map { work in
            var w = work
            if w["category_id"] as? String == "realism" { w.removeValue(forKey: "department_id") }
            return w
        }
        try JSONSerialization.data(withJSONObject: dataset).write(to: dir.appendingPathComponent(DatasetFiles.dataset))
        // Taxonomy: take `realism` out of every department and clear its department_id.
        var taxonomy = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: src.appendingPathComponent(DatasetFiles.taxonomy)))
                as? [String: Any])
        var departments = try #require(taxonomy["departments"] as? [[String: Any]])
        for i in departments.indices {
            departments[i]["categories"] = (departments[i]["categories"] as! [String]).filter { $0 != "realism" }
        }
        taxonomy["departments"] = departments
        var categories = try #require(taxonomy["categories"] as? [[String: Any]])
        for i in categories.indices where categories[i]["id"] as? String == "realism" {
            categories[i].removeValue(forKey: "department_id")
        }
        taxonomy["categories"] = categories
        try JSONSerialization.data(withJSONObject: taxonomy).write(to: dir.appendingPathComponent(DatasetFiles.taxonomy))
        // Onboarding: an unknown exemplar and an unknown choice id.
        var onboarding = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: src.appendingPathComponent(DatasetFiles.onboarding)))
                as? [String: Any])
        var choices = try #require(onboarding["choices"] as? [[String: Any]])
        var exemplars = choices[0]["exemplars"] as! [[String: Any]]
        exemplars[0]["artwork_id"] = "no-such-work"
        choices[0]["exemplars"] = exemplars
        choices[1]["id"] = "baroque_era"
        onboarding["choices"] = choices
        try JSONSerialization.data(withJSONObject: onboarding).write(to: dir.appendingPathComponent(DatasetFiles.onboarding))

        let report = DatasetValidator.validate(
            resourcesDirectory: dir, imagesDirectory: DatasetFiles.artworksDirectory(in: src),
            options: ValidationOptions(runGenerationProbes: false))
        let codes = Set(report.errors.map(\.code))
        #expect(codes.contains("category_department_count"))
        #expect(codes.contains("artwork_without_department"))
        #expect(codes.contains("onboarding_artwork_unresolved"))
        #expect(codes.contains("onboarding_choice_unknown"))
    }

    /// A department added to taxonomy.json (with an onboarding choice) works without code changes:
    /// it loads, becomes a content pack, validates, and survives onboarding sanitising.
    @Test func newDepartmentByDataAlone() throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let src = TestSupport.resourcesDirectory
        for file in [DatasetFiles.tasteBaseline] {
            try FileManager.default.copyItem(at: src.appendingPathComponent(file), to: dir.appendingPathComponent(file))
        }
        func load(_ file: String) throws -> [String: Any] {
            try #require(
                try JSONSerialization.jsonObject(with: Data(contentsOf: src.appendingPathComponent(file))) as? [String: Any])
        }
        func save(_ object: [String: Any], _ file: String) throws {
            try JSONSerialization.data(withJSONObject: object).write(to: dir.appendingPathComponent(file))
        }
        let newID = "drawings_watercolours"
        // Taxonomy: move one category (from the department with most categories) into a new department.
        var taxonomy = try load(DatasetFiles.taxonomy)
        var departments = try #require(taxonomy["departments"] as? [[String: Any]])
        let donor = try #require(departments.indices.max {
            ($0 == $1 ? 0 : (departments[$0]["categories"] as! [String]).count)
                < (departments[$1]["categories"] as! [String]).count
        })
        var donorCategories = departments[donor]["categories"] as! [String]
        let moved = donorCategories.removeLast()
        departments[donor]["categories"] = donorCategories
        departments.append(["id": newID, "label": "Drawings & Watercolours", "categories": [moved]])
        taxonomy["departments"] = departments
        var categories = try #require(taxonomy["categories"] as? [[String: Any]])
        for i in categories.indices where categories[i]["id"] as? String == moved {
            categories[i]["department_id"] = newID
        }
        taxonomy["categories"] = categories
        try save(taxonomy, DatasetFiles.taxonomy)
        // Dataset: works of the moved category follow it.
        var dataset = try load(DatasetFiles.dataset)
        var movedWorks: [String] = []
        dataset["artworks"] = (dataset["artworks"] as! [[String: Any]]).map { work in
            var w = work
            if w["category_id"] as? String == moved {
                w["department_id"] = newID
                if let id = w["id"] as? String { movedWorks.append(id) }
            }
            return w
        }
        try save(dataset, DatasetFiles.dataset)
        // Onboarding: a step-2 choice for the new department, reusing an existing choice's exemplars.
        var onboarding = try load(DatasetFiles.onboarding)
        var choices = try #require(onboarding["choices"] as? [[String: Any]])
        let template = try #require(choices.first { ($0["step"] as? Int) == 2 })
        choices.append(["id": newID, "step": 2, "label": "Drawings & Watercolours", "exemplars": template["exemplars"] ?? []])
        onboarding["choices"] = choices
        try save(onboarding, DatasetFiles.onboarding)

        let data = try BundledDataset(resourcesDirectory: dir, imagesDirectory: DatasetFiles.artworksDirectory(in: src))
        let id = DepartmentID(newID)
        #expect(data.departments.contains { $0.id == id && $0.label == "Drawings & Watercolours" })
        let pack = try #require(data.contentPacks.first { $0.id == id })
        #expect(pack.artworkCount == movedWorks.filter { data.artwork(ArtworkID($0)) != nil }.count)
        #expect(data.onboarding.choice(newID)?.department == id)
        #expect(OnboardingService.sanitized(OnboardingAnswers(departments: [id]), dataset: data).departments == [id])
        #expect(TastePrior.from(answers: OnboardingAnswers(departments: [id])).seedBuckets.allSatisfy { !$0.hasPrefix("era:") },
            "a department without typical era buckets is era-neutral")

        let report = DatasetValidator.validate(
            resourcesDirectory: dir, imagesDirectory: DatasetFiles.artworksDirectory(in: src),
            options: ValidationOptions(runGenerationProbes: false))
        let departmentCodes: Set<String> = [
            "departments_missing", "duplicate_department_id", "unknown_department_category", "unknown_department",
            "department_mismatch", "category_department_count", "artwork_without_department", "onboarding_choice_unknown",
        ]
        #expect(report.errors.filter { departmentCodes.contains($0.code) }.isEmpty, "\(report.errors.map(\.message))")
    }
}
