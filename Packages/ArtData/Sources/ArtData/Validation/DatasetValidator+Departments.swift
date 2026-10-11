import ArtCore
import Foundation

extension DatasetValidator {
    /// Every active category belongs to exactly one department (and its own `department_id`, if
    /// set, agrees); department member lists name real categories; every playable artwork
    /// resolves to a department.
    static func checkDepartments(pool: GamePool, taxonomy: Taxonomy, report: inout DatasetValidationReport) {
        guard !taxonomy.departments.isEmpty else {
            report.add(.error, "departments_missing", "taxonomy.json has no departments")
            return
        }
        let categoryIDs = Set(taxonomy.categories.map(\.id))
        var seen = Set<DepartmentID>()
        var memberships: [CategoryID: [DepartmentID]] = [:]
        for d in taxonomy.departments {
            if !seen.insert(d.id).inserted { report.add(.error, "duplicate_department_id", "department \(d.id) repeats") }
            for c in d.categories {
                if !categoryIDs.contains(c) {
                    report.add(.error, "unknown_department_category", "department \(d.id) lists unknown category \(c)")
                }
                memberships[c, default: []].append(d.id)
            }
        }
        for c in taxonomy.categories {
            let owners = memberships[c.id] ?? []
            if let own = c.departmentID {
                if !seen.contains(own) {
                    report.add(.error, "unknown_department", "category \(c.id) has unknown department_id \(own)")
                } else if !owners.isEmpty && !owners.contains(own) {
                    report.add(.error, "department_mismatch",
                        "category \(c.id) says \(own) but is listed by \(owners.map(\.rawValue).joined(separator: ", "))")
                }
            }
            guard c.active else { continue }
            let all = Set(owners + (c.departmentID.map { [$0] } ?? []))
            if all.count != 1 || owners.count > 1 {
                report.add(.error, "category_department_count",
                    "active category \(c.id) belongs to \(all.count) departments (listed by \(owners.count)); needs exactly 1")
            }
        }
        var unresolved: [ArtworkID] = []
        for a in pool.artworks {
            if let explicit = a.departmentID, !seen.contains(explicit) {
                report.add(.error, "unknown_department", "department_id \(explicit) is not in the taxonomy", a.id)
            }
            if pool.department(of: a) == nil { unresolved.append(a.id) }
        }
        for id in unresolved { report.add(.error, "artwork_without_department", "artwork resolves to no department", id) }
        let counts = pool.departments.map { "\($0.id) \(pool.artworkIDs(in: $0.id).count)" }.joined(separator: ", ")
        report.add(.info, "department_sizes", "works per department: \(counts)")
    }

    /// `onboarding.json`: decodes, schema 1, unique ids, ids map to questionnaire answers, 2–3
    /// exemplars with captions ≤ 90 characters, every exemplar is a playable artwork whose image
    /// files exist.
    static func checkOnboarding(
        in directory: URL, pool: GamePool, locator: ImageLocator, checkFiles: Bool,
        report: inout DatasetValidationReport
    ) {
        guard let catalog: OnboardingCatalog = decodeFile(DatasetFiles.onboarding, in: directory, report: &report) else {
            return
        }
        if catalog.schemaVersion != 1 {
            report.add(.error, "onboarding_schema", "onboarding.json schema_version \(catalog.schemaVersion), expected 1")
        }
        if let id = catalog.datasetID, id != report.datasetVersion {
            report.add(.warning, "onboarding_dataset_mismatch",
                "onboarding.json dataset_id \(id) differs from dataset \(report.datasetVersion ?? "?")")
        }
        let departments = Set(pool.departments.map(\.id))
        var ids = Set<String>()
        for choice in catalog.choices {
            if !ids.insert(choice.id).inserted {
                report.add(.error, "onboarding_duplicate_choice", "choice \(choice.id) repeats")
            }
            let maps: Bool
            switch choice.step {
            case 1: maps = choice.era != nil
            case 2: maps = choice.department.map { departments.contains($0) } ?? false
            case 3: maps = choice.subject != nil
            case 4: maps = choice.mood != nil
            case 5: maps = OnboardingAnswers.Intent(rawValue: choice.id) != nil
            default: maps = false
            }
            if !maps {
                report.add(.error, "onboarding_choice_unknown",
                    "choice \(choice.id) (step \(choice.step)) does not map to a questionnaire answer")
            }
            if choice.step != 5 && !(2...3).contains(choice.exemplars.count) {
                report.add(.warning, "onboarding_exemplar_count", "choice \(choice.id) has \(choice.exemplars.count) exemplars (2–3)")
            }
            for ex in choice.exemplars {
                if ex.caption.isEmpty || ex.caption.count > 90 {
                    report.add(.warning, "onboarding_caption_length", "choice \(choice.id) caption length \(ex.caption.count)", ex.artworkID)
                }
                guard let work = pool.artwork(ex.artworkID) else {
                    report.add(.error, "onboarding_artwork_unresolved",
                        "choice \(choice.id) exemplar is not a playable artwork", ex.artworkID)
                    continue
                }
                guard checkFiles else { continue }
                for rendition in ImageRendition.allCases {
                    guard let url = locator.url(for: work, rendition: rendition),
                        (try? ImageFileFormat.sniff(fileAt: url)) != nil
                    else {
                        report.add(.error, "onboarding_image_missing",
                            "choice \(choice.id) exemplar has no readable \(rendition.rawValue) image", work.id)
                        continue
                    }
                }
            }
        }
        report.add(.info, "onboarding_choices", "\(catalog.choices.count) onboarding choices")
    }
}
