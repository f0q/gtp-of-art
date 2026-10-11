import CoreGraphics

/// Spacing rule for labels on nested brackets (the Bid reveal's ≤2× / ≤5× / ≤10× tiers), so labels
/// never overlap however narrow the brackets get.
///
/// Rule: labels are placed widest bracket first. Each label sits above its bracket, trailing-aligned
/// to the bracket's right edge (clamped inside the track). It takes the lowest row where it clears every
/// label already in that row by `gap`; rows are capped at `maxRows` (`Tokens.Layout.bracketLabelMaxRows`).
/// A label that fits in no row is dropped. The widest bracket's label is placed first, so it always
/// shows. When brackets are very narrow this degrades to a single label on the widest bracket.
nonisolated public enum BracketLabelLayout {
    /// One label to place.
    public struct Item: Sendable, Equatable {
        /// Caller's identifier (e.g. the tier).
        public let id: Int
        /// Bracket left edge (track coordinates).
        public let left: CGFloat
        /// Bracket right edge (track coordinates).
        public let right: CGFloat
        /// Measured label width.
        public let labelWidth: CGFloat

        /// Creates an item.
        public init(id: Int, left: CGFloat, right: CGFloat, labelWidth: CGFloat) {
            self.id = id
            self.left = left
            self.right = right
            self.labelWidth = labelWidth
        }
    }

    /// Where a label goes; `row` 0 is nearest the bracket, rows stack upward.
    public struct Placement: Sendable, Equatable {
        /// Item id.
        public let id: Int
        /// Label leading x (track coordinates).
        public let minX: CGFloat
        /// Row index (0 = nearest the bracket).
        public let row: Int
    }

    /// Places labels; dropped labels are absent from the result.
    /// - Parameters:
    ///   - items: Brackets with measured label widths, in any order.
    ///   - trackWidth: Width labels must stay within.
    ///   - gap: Minimum horizontal gap between labels in one row.
    ///   - maxRows: Rows available (≥ 1).
    public static func place(_ items: [Item], trackWidth: CGFloat,
                             gap: CGFloat = Tokens.Space.xs,
                             maxRows: Int = Int(Tokens.Layout.bracketLabelMaxRows)) -> [Placement] {
        let ordered = items.sorted { ($0.right - $0.left) > ($1.right - $1.left) }
        var rows: [[ClosedRange<CGFloat>]] = Array(repeating: [], count: max(1, maxRows))
        var result: [Placement] = []
        for item in ordered {
            let maxX = min(max(item.right, item.labelWidth), trackWidth)
            let minX = max(0, maxX - item.labelWidth)
            let span = minX...(minX + item.labelWidth)
            for row in rows.indices {
                let clear = rows[row].allSatisfy { other in
                    span.upperBound + gap <= other.lowerBound || other.upperBound + gap <= span.lowerBound
                }
                if clear {
                    rows[row].append(span)
                    result.append(Placement(id: item.id, minX: minX, row: row))
                    break
                }
            }
        }
        return result
    }
}
