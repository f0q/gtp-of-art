/// The artworks and taxonomy a game draws from, normalised for deterministic selection.
///
/// Artworks, categories and departments are sorted by id (UTF-8 byte order) on construction, so
/// the input order of the dataset file never affects results.
public struct GamePool: Sendable, Equatable {
    public let artworks: [Artwork]
    public let categories: [Category]
    public let departments: [Department]
    private let artworkIndex: [ArtworkID: Int]
    private let categoryIndex: [CategoryID: Int]
    private let artworkDepartment: [ArtworkID: DepartmentID]
    private let departmentArtworks: [DepartmentID: [ArtworkID]]
    /// Categories that may be the *truth* of a quiz question: active and with ≥ `minQuizItems`
    /// works whose primary category it is.
    public let quizCategoryIDs: Set<CategoryID>
    /// Active categories (any may be a quiz distractor).
    public let activeCategoryIDs: Set<CategoryID>

    public init(artworks: [Artwork], categories: [Category]) {
        self.init(artworks: artworks, categories: categories, departments: [])
    }

    public init(artworks: [Artwork], categories: [Category], departments: [Department]) {
        let sortedArtworks = artworks.sorted { $0.id < $1.id }
        let sortedCategories = categories.sorted { $0.id < $1.id }
        let sortedDepartments = departments.sorted { $0.id < $1.id }
        self.artworks = sortedArtworks
        self.categories = sortedCategories
        self.departments = sortedDepartments
        var aIndex: [ArtworkID: Int] = [:]
        for (i, a) in sortedArtworks.enumerated() { aIndex[a.id] = i }
        var cIndex: [CategoryID: Int] = [:]
        for (i, c) in sortedCategories.enumerated() { cIndex[c.id] = i }
        artworkIndex = aIndex
        categoryIndex = cIndex
        var counts: [CategoryID: Int] = [:]
        for a in sortedArtworks { counts[a.category, default: 0] += 1 }
        quizCategoryIDs = Set(
            sortedCategories.filter { $0.active && counts[$0.id, default: 0] >= $0.minQuizItems }.map(\.id))
        activeCategoryIDs = Set(sortedCategories.filter(\.active).map(\.id))

        // Category → department: the category's own department_id, else the first department
        // (in id order) listing it.
        var categoryDepartment: [CategoryID: DepartmentID] = [:]
        for d in sortedDepartments.reversed() {
            for c in d.categories { categoryDepartment[c] = d.id }
        }
        for c in sortedCategories {
            if let d = c.departmentID { categoryDepartment[c.id] = d }
        }
        var byArtwork: [ArtworkID: DepartmentID] = [:]
        var byDepartment: [DepartmentID: [ArtworkID]] = [:]
        for a in sortedArtworks {
            if let d = a.departmentID ?? categoryDepartment[a.category] {
                byArtwork[a.id] = d
                byDepartment[d, default: []].append(a.id)
            }
        }
        artworkDepartment = byArtwork
        departmentArtworks = byDepartment
    }

    public func artwork(_ id: ArtworkID) -> Artwork? {
        artworkIndex[id].map { artworks[$0] }
    }

    public func category(_ id: CategoryID) -> Category? {
        categoryIndex[id].map { categories[$0] }
    }

    /// The artwork's department: its explicit `department_id`, else its primary category's
    /// department (the category's `department_id`, else the department listing the category).
    public func department(of artwork: Artwork) -> DepartmentID? {
        artworkDepartment[artwork.id]
    }

    /// Department of an artwork id in this pool.
    public func department(of id: ArtworkID) -> DepartmentID? {
        artworkDepartment[id]
    }

    /// Artworks of a department, sorted by id.
    public func artworkIDs(in department: DepartmentID) -> [ArtworkID] {
        departmentArtworks[department] ?? []
    }
}
