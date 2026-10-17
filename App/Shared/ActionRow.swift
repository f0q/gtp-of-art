import ArtDesign
import SwiftUI

/// A bottom bar's secondary actions (Home, Share, …): equal widths and equal heights, labels on one
/// line. When the titled row cannot fit (a narrow phone, a large non-accessibility type size) the
/// row goes icon-only, keeping each title as its accessibility label; at accessibility sizes the
/// actions stack full width with their titles.
///
/// Put a `Label` in each action and give it `.actionRowItem()`.
struct ActionRow<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            stacked
        } else {
            // Three titled secondary buttons measure 3 × ~112 pt on iOS 26 (glass padding): with
            // `Space.s` gaps that is 351 pt, which fits a 390 pt phone's 358 pt; `Space.m` did not.
            ViewThatFits(in: .horizontal) {
                EqualWidthRow(spacing: Tokens.Space.s) { content }
                EqualWidthRow(spacing: Tokens.Space.s) { content }.labelStyle(.iconOnly)
                stacked
            }
        }
    }

    /// Full-width actions, each at its own content height: `actionRowItem()` lets items fill the
    /// row's slot, so the stack must stop them from filling the screen too.
    private var stacked: some View {
        VStack(spacing: Tokens.Space.s) { content }
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    /// An `ActionRow` action's label: one line, filling the slot the row gives it.
    func actionRowItem() -> some View {
        lineLimit(1).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Lays children out in one row of equal slots. Its ideal width is `count ×` the widest child's
/// ideal width, so `ViewThatFits` only picks it when every child fits its slot untruncated; every
/// slot takes the tallest child's height.
struct EqualWidthRow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        let gaps = spacing * CGFloat(subviews.count - 1)
        let width = (ideals.map(\.width).max() ?? 0) * CGFloat(subviews.count) + gaps
        let height = ideals.map(\.height).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let gaps = spacing * CGFloat(subviews.count - 1)
        let slot = max(0, (bounds.width - gaps) / CGFloat(subviews.count))
        for (i, subview) in subviews.enumerated() {
            let origin = CGPoint(x: bounds.minX + CGFloat(i) * (slot + spacing), y: bounds.minY)
            subview.place(at: origin, anchor: .topLeading, proposal: ProposedViewSize(width: slot, height: bounds.height))
        }
    }
}
