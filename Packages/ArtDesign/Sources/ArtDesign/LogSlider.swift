import Foundation
import SwiftUI

// MARK: - Pure scale (unit-tested; mirrors ArtCore's bid mapping)

/// The bid slider's logarithmic scale: integer positions 0…700, 0.01 decade per step,
/// `guessMilli = 2000 + 10 × position`, so position 0 = $100 and 700 = $1B (plan Part D5).
nonisolated public enum LogPriceScale {
    /// Highest position.
    public static let maxPosition = Int(Tokens.Gesture.sliderPositions)
    /// All valid positions.
    public static let fullRange = 0...maxPosition
    /// Positions per decade.
    public static let positionsPerDecade = 100
    /// log10(price) × 1000 at position 0.
    public static let baseMilli = 2000
    /// Milli-decades per position.
    public static let milliPerPosition = 10

    /// Clamps to 0…700.
    public static func clamp(_ position: Int) -> Int { min(max(position, 0), maxPosition) }

    /// log10(price) × 1000 for a position (the integer value ArtCore scores with).
    public static func milli(forPosition position: Int) -> Int {
        baseMilli + milliPerPosition * clamp(position)
    }

    /// Exact USD price for a position.
    public static func price(forPosition position: Int) -> Double {
        pow(10, Double(milli(forPosition: position)) / 1000)
    }

    /// Nearest position for a USD price (clamped).
    public static func position(forPrice price: Double) -> Int {
        guard price > 0, price.isFinite else { return 0 }
        let p = (log10(price) * 1000 - Double(baseMilli)) / Double(milliPerPosition)
        return clamp(Int(p.rounded()))
    }

    /// Price rounded to 2 significant figures (what the player sees and commits).
    public static func displayPrice(forPosition position: Int) -> Double {
        roundToSignificantFigures(price(forPosition: position), 2)
    }

    /// Rounds `value` to `figures` significant figures.
    public static func roundToSignificantFigures(_ value: Double, _ figures: Int) -> Double {
        guard value > 0, value.isFinite else { return 0 }
        let magnitude = floor(log10(value)) + 1 - Double(figures)
        let factor = pow(10, magnitude)
        return (value / factor).rounded() * factor
    }

    /// "$850", "$57K", "$2.8M", "$450M", "$1B": 2 significant figures + suffix (plan Part E8).
    public static func format(_ price: Double) -> String {
        let v = roundToSignificantFigures(price, 2)
        let units: [(Double, String)] = [(1e9, "B"), (1e6, "M"), (1e3, "K")]
        for (scale, suffix) in units where v >= scale {
            return "$" + trimmed(v / scale) + suffix
        }
        return "$" + trimmed(v)
    }

    private static func trimmed(_ x: Double) -> String {
        let r = (x * 10).rounded() / 10
        return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
    }

    /// Formatted 2-sf price for a position.
    public static func label(forPosition position: Int) -> String {
        format(price(forPosition: position))
    }

    /// Decade ticks (0, 100, …, 700), labelled $100 … $1B.
    public static let decadePositions: [Int] = Array(stride(from: 0, through: maxPosition, by: positionsPerDecade))

    /// Minor ticks at 2× and 5× within each decade (offsets round(100·log10 2) = 30 and 70).
    public static let minorPositions: [Int] = makeMinorPositions()

    /// Offset of a multiplier's tick within a decade, in positions (2× → 30, 5× → 70).
    private static func minorOffset(_ multiplier: Double) -> Int {
        let decades: Double = log10(multiplier)
        let positions: Double = decades * Double(positionsPerDecade)
        return Int(positions.rounded())
    }

    private static func makeMinorPositions() -> [Int] {
        let offsets: [Int] = [minorOffset(2), minorOffset(5)]
        var result: [Int] = []
        for decade: Int in decadePositions.dropLast() {
            for offset: Int in offsets {
                result.append(decade + offset)
            }
        }
        return result
    }

    /// Number of decade ticks at or below `position` minus one; changes exactly at decade crossings.
    public static func decadeIndex(_ position: Int) -> Int { clamp(position) / positionsPerDecade }

    /// Number of minor ticks at or below `position`; changes exactly at minor-tick crossings.
    public static func minorIndex(_ position: Int) -> Int {
        let p = clamp(position)
        return minorPositions.reduce(0) { $0 + ($1 <= p ? 1 : 0) }
    }

    /// The next position (in `direction` = ±1) whose 2-sf display price differs from the current one.
    /// Used by the −/+ steppers so every tap visibly changes the bid.
    public static func nextDistinctPosition(from position: Int, direction: Int,
                                            in bounds: ClosedRange<Int> = fullRange) -> Int {
        let step = direction >= 0 ? 1 : -1
        let current = displayPrice(forPosition: position)
        var p = position
        while true {
            let next = p + step
            guard bounds.contains(next) else { return min(max(p, bounds.lowerBound), bounds.upperBound) }
            p = next
            if displayPrice(forPosition: p) != current { return p }
        }
    }
}

// MARK: - View

/// Geometry shared by the slider's layers: maps positions to x within the track width.
nonisolated struct LogSliderGeometry: Equatable {
    let bounds: ClosedRange<Int>
    let width: CGFloat

    static let thumbDiameter: CGFloat = Tokens.Size.minTarget - Tokens.Space.l
    static let trackHeight: CGFloat = Tokens.Space.xs
    /// Vertical centre of the track inside the slider.
    static let trackY: CGFloat = thumbDiameter / 2 + Tokens.Space.l
    /// Total control height: thumb, ticks and labels.
    static let height: CGFloat = thumbDiameter + Tokens.Space.l * 2 + Tokens.Space.xl

    /// Horizontal inset so the thumb never overhangs the track ends (or the steppers).
    static let inset: CGFloat = thumbDiameter / 2

    var span: Double { Double(max(bounds.upperBound - bounds.lowerBound, 1)) }

    /// Usable track length between the insets.
    var usableWidth: CGFloat { max(width - Self.inset * 2, 1) }

    func x(for position: Int) -> CGFloat {
        let fraction: Double = Double(position - bounds.lowerBound) / span
        return Self.inset + CGFloat(fraction) * usableWidth
    }

    /// Continuous position under an x coordinate.
    func position(atX x: CGFloat) -> Double {
        let fraction: Double = Double((x - Self.inset) / usableWidth)
        return Double(bounds.lowerBound) + fraction * span
    }

    var pointsPerPosition: CGFloat { usableWidth / CGFloat(span) }
}

/// Logarithmic bid slider: custom track, decade labels, minor ticks, decade/minor haptics, fine scrub
/// (drag ≥ 60pt above or below the track to move at 0.25×, labelled "Fine"), VoiceOver adjustable
/// (±10 positions) and optional −/+ steppers.
public struct LogSlider: View {
    @Binding private var position: Int
    private let bounds: ClosedRange<Int>
    private let showsSteppers: Bool
    private let accessibilityLabel: Text

    /// Creates a slider.
    /// - Parameters:
    ///   - position: Integer position 0…700 (see `LogPriceScale`).
    ///   - bounds: Sub-range to show, rounded to decades (e.g. `200...700` for $10K–$1B).
    ///   - showsSteppers: Show −/+ buttons that step to the next distinct 2-sf price.
    ///   - accessibilityLabel: VoiceOver label (default "Your bid").
    public init(position: Binding<Int>, bounds: ClosedRange<Int> = LogPriceScale.fullRange,
                showsSteppers: Bool = true, accessibilityLabel: Text = Text("Your bid")) {
        _position = position
        self.bounds = LogPriceScale.clamp(bounds.lowerBound)...LogPriceScale.clamp(bounds.upperBound)
        self.showsSteppers = showsSteppers
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: Tokens.Space.s) {
            if showsSteppers {
                LogSliderStepper(direction: -1, position: $position, bounds: bounds)
            }
            LogSliderTrack(position: $position, bounds: bounds, accessibilityLabel: accessibilityLabel)
            if showsSteppers {
                LogSliderStepper(direction: 1, position: $position, bounds: bounds)
            }
        }
        .artHaptic(.sliderDecade, trigger: LogPriceScale.decadeIndex(position))
        .artHaptic(.sliderMinor, trigger: LogPriceScale.minorIndex(position))
    }
}

/// The interactive track: layers + drag gesture + VoiceOver adjustable action.
struct LogSliderTrack: View {
    @Binding var position: Int
    let bounds: ClosedRange<Int>
    let accessibilityLabel: Text

    @State private var exactPosition: Double = 0
    @State private var lastX: CGFloat?
    @State private var isFine: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let geometry = LogSliderGeometry(bounds: bounds, width: proxy.size.width)
            LogSliderLayers(geometry: geometry, position: position, isFine: isFine)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .contentShape(Rectangle())
                .gesture(dragGesture(geometry))
        }
        .frame(minHeight: LogSliderGeometry.height)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(Text(LogPriceScale.label(forPosition: position)))
        .accessibilityAdjustableAction(adjust)
    }

    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        let step: Int = Int(Tokens.Gesture.sliderAccessibilityStep)
        switch direction {
        case .increment: set(position + step)
        case .decrement: set(position - step)
        @unknown default: break
        }
    }

    private func dragGesture(_ geometry: LogSliderGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in dragChanged(value, geometry: geometry) }
            .onEnded { _ in
                lastX = nil
                withAnimation(ArtMotion.fast) { isFine = false }
            }
    }

    private func dragChanged(_ value: DragGesture.Value, geometry: LogSliderGeometry) {
        if lastX == nil {
            let thumbX: CGFloat = geometry.x(for: position)
            if abs(value.startLocation.x - thumbX) > LogSliderGeometry.thumbDiameter {
                // Tap away from the thumb jumps there.
                exactPosition = geometry.position(atX: value.startLocation.x)
                set(Int(exactPosition.rounded()))
            } else {
                exactPosition = Double(position)
            }
            lastX = value.startLocation.x
        }
        let distance: CGFloat = abs(value.location.y - LogSliderGeometry.trackY)
        let fine: Bool = distance >= Tokens.Gesture.fineScrubDistance
        if fine != isFine {
            withAnimation(ArtMotion.fast) { isFine = fine }
        }
        let factor: CGFloat = fine ? Tokens.Gesture.fineScrubFactor : 1
        let dx: CGFloat = value.location.x - (lastX ?? value.location.x)
        lastX = value.location.x
        let delta: Double = Double(dx * factor / max(geometry.pointsPerPosition, 0.0001))
        let lower: Double = Double(bounds.lowerBound)
        let upper: Double = Double(bounds.upperBound)
        exactPosition = min(max(exactPosition + delta, lower), upper)
        set(Int(exactPosition.rounded()))
    }

    private func set(_ newValue: Int) {
        let clamped: Int = min(max(newValue, bounds.lowerBound), bounds.upperBound)
        if clamped != position { position = clamped }
    }
}

/// Static drawing of the slider: track, gilt fill, ticks, labels, thumb, "Fine" badge.
struct LogSliderLayers: View {
    let geometry: LogSliderGeometry
    let position: Int
    let isFine: Bool

    var body: some View {
        let thumbX: CGFloat = geometry.x(for: position)
        ZStack(alignment: .topLeading) {
            LogSliderRail(width: geometry.width, fillWidth: thumbX)
            LogSliderTicks(geometry: geometry)
            LogSliderLabels(geometry: geometry)
            LogSliderThumb(isFine: isFine)
                .offset(x: thumbX - LogSliderGeometry.thumbDiameter / 2,
                        y: LogSliderGeometry.trackY - LogSliderGeometry.thumbDiameter / 2)
            if isFine {
                LogSliderFineBadge()
                    .offset(x: thumbX - LogSliderGeometry.thumbDiameter / 2, y: 0)
            }
        }
    }
}

/// Background rail and the gilt fill up to the thumb.
struct LogSliderRail: View {
    let width: CGFloat
    let fillWidth: CGFloat

    var body: some View {
        let h: CGFloat = LogSliderGeometry.trackHeight
        let y: CGFloat = LogSliderGeometry.trackY - h / 2
        ZStack(alignment: .topLeading) {
            Capsule()
                .fill(Tokens.Color.bgElevated)
                .frame(width: width, height: h)
            Capsule()
                .fill(Tokens.Color.accentGilt)
                .frame(width: max(h, fillWidth), height: h)
        }
        .offset(y: y)
    }
}

/// Decade ticks (taller) and 2×/5× minor ticks (shorter, dimmer).
struct LogSliderTicks: View {
    let geometry: LogSliderGeometry

    var body: some View {
        let decades: [Int] = LogPriceScale.decadePositions.filter(geometry.bounds.contains)
        let minors: [Int] = LogPriceScale.minorPositions.filter(geometry.bounds.contains)
        let y: CGFloat = LogSliderGeometry.trackY + Tokens.Space.xs
        ZStack(alignment: .topLeading) {
            ForEach(minors, id: \.self) { p in
                tick(height: Tokens.Space.s, color: Tokens.Color.textSecondary.opacity(0.5))
                    .offset(x: geometry.x(for: p) - Self.tickWidth / 2, y: y)
            }
            ForEach(decades, id: \.self) { p in
                tick(height: Tokens.Space.m, color: Tokens.Color.textSecondary)
                    .offset(x: geometry.x(for: p) - Self.tickWidth / 2, y: y)
            }
        }
        .accessibilityHidden(true)
    }

    static let tickWidth: CGFloat = Tokens.Size.hairline * 2

    private func tick(height: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: Self.tickWidth, height: height)
    }
}

/// Decade labels ($100 … $1B); every other label at AX sizes so they never collide.
/// Inner labels are centred on their tick; the first and last are pinned inside the track edges so
/// they are never clipped by the screen edge or the −/+ steppers.
struct LogSliderLabels: View {
    let geometry: LogSliderGeometry
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let decades: [Int] = LogPriceScale.decadePositions.filter(geometry.bounds.contains)
        let shown: [Int] = dynamicTypeSize >= .accessibility1
            ? decades.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)
            : decades
        let y: CGFloat = LogSliderGeometry.trackY + Tokens.Space.l + Tokens.Space.xs
        ZStack(alignment: .topLeading) {
            ForEach(shown, id: \.self) { p in
                LogSliderLabel(text: LogPriceScale.label(forPosition: p),
                               placement: placement(for: p, decades: decades),
                               geometry: geometry)
            }
        }
        .offset(y: y)
        .accessibilityHidden(true)
    }

    private func placement(for p: Int, decades: [Int]) -> LogSliderLabel.Placement {
        if p == decades.first { return .leadingEdge }
        if p == decades.last { return .trailingEdge }
        return .centred(on: p)
    }
}

/// One decade label.
struct LogSliderLabel: View {
    enum Placement: Equatable {
        case leadingEdge
        case trailingEdge
        case centred(on: Int)
    }

    let text: String
    let placement: Placement
    let geometry: LogSliderGeometry

    var body: some View {
        let label = Text(text)
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(Tokens.Color.textSecondary)
            .fixedSize()
        switch placement {
        case .leadingEdge:
            label.frame(width: geometry.width, alignment: .leading)
        case .trailingEdge:
            label.frame(width: geometry.width, alignment: .trailing)
        case .centred(let position):
            // A frame symmetric around the tick keeps the label centred on it.
            let x: CGFloat = geometry.x(for: position)
            let half: CGFloat = min(x, geometry.width - x)
            label
                .frame(width: half * 2, alignment: .center)
                .offset(x: x - half)
        }
    }
}

/// Solid (not glass) thumb: it moves, and glass is reserved for static chrome.
struct LogSliderThumb: View {
    let isFine: Bool

    var body: some View {
        Circle()
            .fill(Tokens.Color.bgSurface)
            .overlay(Circle().stroke(Tokens.Color.accentGilt, lineWidth: Tokens.Space.xxs))
            .frame(width: LogSliderGeometry.thumbDiameter, height: LogSliderGeometry.thumbDiameter)
            .scaleEffect(isFine ? 0.85 : 1)
    }
}

/// "Fine" badge shown above the thumb while fine scrubbing.
struct LogSliderFineBadge: View {
    var body: some View {
        Text("Fine")
            .artTextStyle(Tokens.Typography.provenance)
            .foregroundStyle(Tokens.Color.textSecondary)
            .fixedSize()
            .accessibilityHidden(true)
    }
}

/// −/+ button that steps to the next distinct 2-sf price.
struct LogSliderStepper: View {
    let direction: Int
    @Binding var position: Int
    let bounds: ClosedRange<Int>

    var body: some View {
        Button(action: step) {
            Image(systemName: direction < 0 ? "minus" : "plus")
                .font(ArtFont.label)
                .frame(width: Tokens.Size.minTarget, height: Tokens.Size.minTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Tokens.Color.textPrimary)
        .background(Tokens.Color.bgElevated, in: Circle())
        .accessibilityLabel(Text(direction < 0 ? "Lower bid" : "Raise bid"))
    }

    private func step() {
        position = LogPriceScale.nextDistinctPosition(from: position, direction: direction, in: bounds)
    }
}
