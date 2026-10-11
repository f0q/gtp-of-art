import Observation
import SwiftUI

// MARK: - Pure decision logic (unit-tested)

/// Direction a card leaves the stack.
nonisolated public enum SwipeDirection: Sendable, Equatable, CaseIterable {
    /// Left: pass.
    case pass
    /// Right: like ("keep").
    case like

    /// -1 for pass, +1 for like.
    public var sign: CGFloat { self == .like ? 1 : -1 }

    init(sign value: CGFloat) { self = value >= 0 ? .like : .pass }
}

/// What a finished drag means.
nonisolated public enum SwipeOutcome: Sendable, Equatable {
    /// The card leaves in this direction.
    case commit(SwipeDirection)
    /// Swipe up: open details; the card stays.
    case details
    /// Spring back to centre.
    case cancel
}

/// Swipe thresholds and the pure functions the card stack uses (Part C4 / D6).
nonisolated public struct SwipePhysics: Sendable, Equatable {
    /// Commit when |x| > ratio × width.
    public var commitRatio: CGFloat
    /// Commit when |velocity.x| ≥ this (pt/s).
    public var commitVelocity: CGFloat
    /// Commit when |predicted end x| > ratio × width.
    public var predictedEndRatio: CGFloat
    /// Rotation clamp (degrees).
    public var maxRotationDegrees: CGFloat
    /// Rotation (degrees) = x / divisor.
    public var rotationDivisor: CGFloat
    /// Swipe up beyond ratio × height opens details.
    public var upRatio: CGFloat

    /// Values from `Tokens.Gesture`.
    public static let standard = SwipePhysics(
        commitRatio: Tokens.Gesture.swipeCommitRatio,
        commitVelocity: Tokens.Gesture.swipeCommitVelocity,
        predictedEndRatio: Tokens.Gesture.swipePredictedEndRatio,
        maxRotationDegrees: Tokens.Gesture.swipeMaxRotationDeg,
        rotationDivisor: Tokens.Gesture.swipeRotationDivisor,
        upRatio: Tokens.Gesture.swipeUpRatio
    )

    /// Creates physics with explicit values (tests, tuning).
    public init(commitRatio: CGFloat, commitVelocity: CGFloat, predictedEndRatio: CGFloat,
                maxRotationDegrees: CGFloat, rotationDivisor: CGFloat, upRatio: CGFloat) {
        self.commitRatio = commitRatio
        self.commitVelocity = commitVelocity
        self.predictedEndRatio = predictedEndRatio
        self.maxRotationDegrees = maxRotationDegrees
        self.rotationDivisor = rotationDivisor
        self.upRatio = upRatio
    }

    /// Decides the outcome of a finished drag. Order: swipe-up details (vertical-dominant), fling
    /// velocity, translation threshold, predicted end; otherwise cancel.
    public func decide(translation: CGSize, predictedEndTranslation: CGSize, velocity: CGSize,
                       cardSize: CGSize) -> SwipeOutcome {
        let width = max(cardSize.width, 1)
        let height = max(cardSize.height, 1)
        let dx = translation.width
        let dy = translation.height
        if -dy > upRatio * height && abs(dy) > abs(dx) {
            return .details
        }
        if abs(velocity.width) >= commitVelocity && abs(velocity.width) > abs(velocity.height) {
            return .commit(SwipeDirection(sign: velocity.width))
        }
        if abs(dx) > commitRatio * width {
            return .commit(SwipeDirection(sign: dx))
        }
        if abs(predictedEndTranslation.width) > predictedEndRatio * width {
            return .commit(SwipeDirection(sign: predictedEndTranslation.width))
        }
        return .cancel
    }

    /// Whether the live drag is past the translation threshold (drives the threshold haptic).
    public func isPastThreshold(translationX x: CGFloat, width: CGFloat) -> Bool {
        abs(x) > commitRatio * max(width, 1)
    }

    /// Card rotation in degrees for a horizontal translation, clamped to ±max.
    public func rotationDegrees(translationX x: CGFloat) -> CGFloat {
        min(max(x / rotationDivisor, -maxRotationDegrees), maxRotationDegrees)
    }

    /// KEEP/PASS stamp opacity, proportional to |x| and reaching 1 at the commit threshold.
    public func stampOpacity(translationX x: CGFloat, width: CGFloat) -> Double {
        Double(min(1, abs(x) / (commitRatio * max(width, 1))))
    }

    /// Progress 0…1 toward the threshold (used to grow the next card from its stacked scale).
    public func progress(translationX x: CGFloat, width: CGFloat) -> CGFloat {
        min(1, abs(x) / (commitRatio * max(width, 1)))
    }
}

// MARK: - Controller (button alternative + undo)

/// Drives a `CardStack` from buttons, VoiceOver or code. Every gesture has a button alternative.
@Observable
public final class CardStackController {
    enum Command: Equatable {
        case swipe(SwipeDirection)
        case undo
    }

    private(set) var command: Command?
    private(set) var serial = 0

    /// Direction of the last committed swipe; `nil` after an undo (one level only).
    public private(set) var lastDirection: SwipeDirection?

    /// Whether `undo()` can restore a card.
    public var canUndo: Bool { lastDirection != nil }

    /// Creates a controller.
    public init() {}

    /// Sends the top card away as if swiped.
    public func swipe(_ direction: SwipeDirection) {
        command = .swipe(direction)
        serial &+= 1
    }

    /// Restores the last swiped card (one level).
    public func undo() {
        guard canUndo else { return }
        command = .undo
        serial &+= 1
    }

    func didCommit(_ direction: SwipeDirection) { lastDirection = direction }
    func didUndo() { lastDirection = nil }
}

// MARK: - View

/// A Tinder-style stack: 3 visible cards, drag on the top card only, KEEP/PASS stamps, haptics,
/// VoiceOver actions, Reduce Motion crossfades. The caller owns `items` (front first) and removes the
/// item in `onSwipe`; for undo it re-inserts the item at the front in `onUndo`.
///
/// No prices are shown while swiping and no glass is drawn on the moving card.
public struct CardStack<Item: Identifiable, Card: View>: View {
    private let items: [Item]
    private let controller: CardStackController
    private let physics: SwipePhysics
    private let onSwipe: (Item, SwipeDirection) -> Void
    private let onUndo: (() -> Void)?
    private let onDetails: ((Item) -> Void)?
    private let card: (Item) -> Card

    @State private var drag: CGSize = .zero
    @State private var isCommitting = false
    @State private var pastThreshold = false
    @State private var commitCount = 0
    @State private var fadingOut = false
    @Environment(\.artReduceMotion) private var reduceMotion

    /// Creates a stack.
    /// - Parameters:
    ///   - items: Cards, front first. Only the first 3 are rendered.
    ///   - controller: Button/VoiceOver/undo driver.
    ///   - physics: Thresholds (defaults to tokens).
    ///   - onSwipe: Called after the fly-out animation; remove the item here.
    ///   - onUndo: Re-insert the last item at the front. `nil` disables undo.
    ///   - onDetails: Swipe-up / VoiceOver "Details". `nil` disables it.
    ///   - card: Card content (artwork + title; never a price).
    public init(items: [Item], controller: CardStackController, physics: SwipePhysics = .standard,
                onSwipe: @escaping (Item, SwipeDirection) -> Void,
                onUndo: (() -> Void)? = nil,
                onDetails: ((Item) -> Void)? = nil,
                @ViewBuilder card: @escaping (Item) -> Card) {
        self.items = items
        self.controller = controller
        self.physics = physics
        self.onSwipe = onSwipe
        self.onUndo = onUndo
        self.onDetails = onDetails
        self.card = card
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                ForEach(Array(visible.enumerated()).reversed(), id: \.element.id) { depth, item in
                    layer(item, depth: depth, size: size)
                }
            }
            .frame(width: size.width, height: size.height)
            .onChange(of: controller.serial) {
                handle(controller.command, size: size)
            }
        }
        .padding(.horizontal, Tokens.Gesture.edgeInset)
        .artHaptic(.swipeThreshold, trigger: pastThreshold) { old, new in !old && new }
        .artHaptic(.swipeCommit, trigger: commitCount)
    }

    private var visible: ArraySlice<Item> { items.prefix(Int(Tokens.Gesture.stackVisibleCount)) }

    @ViewBuilder
    private func layer(_ item: Item, depth: Int, size: CGSize) -> some View {
        let isTop = depth == 0
        let base = card(item)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
            .scaleEffect(scale(depth: depth, width: size.width), anchor: .bottom)
            .offset(y: offsetY(depth: depth, width: size.width))
            .allowsHitTesting(isTop)
            .accessibilityHidden(!isTop)
            .zIndex(Double(-depth))

        if isTop {
            base
                .overlay(alignment: .top) { stamps(width: size.width) }
                .rotationEffect(.degrees(reduceMotion ? 0 : physics.rotationDegrees(translationX: drag.width)),
                                anchor: .bottom)
                .offset(drag)
                .opacity(fadingOut ? 0 : 1)
                .gesture(dragGesture(item: item, size: size))
                .accessibilityElement(children: .combine)
                .accessibilityAction(named: Text("Like")) { commit(.like, item: item, size: size) }
                .accessibilityAction(named: Text("Pass")) { commit(.pass, item: item, size: size) }
                .modifier(DetailsAction(enabled: onDetails != nil) { onDetails?(item) })
                .accessibilityHint(Text("Swipe right to keep, left to pass, or use the actions."))
        } else {
            base
        }
    }

    private func scale(depth: Int, width: CGFloat) -> CGFloat {
        let scales: [CGFloat] = [1, Tokens.Gesture.stackScaleSecond, Tokens.Gesture.stackScaleThird]
        let s = scales[min(depth, scales.count - 1)]
        guard depth > 0 else { return s }
        let previous = scales[depth - 1]
        return s + (previous - s) * physics.progress(translationX: drag.width, width: width)
    }

    private func offsetY(depth: Int, width: CGFloat) -> CGFloat {
        guard depth > 0 else { return 0 }
        let p = physics.progress(translationX: drag.width, width: width)
        return Tokens.Gesture.stackOffset * (CGFloat(depth) - p)
    }

    @ViewBuilder
    private func stamps(width: CGFloat) -> some View {
        let opacity = physics.stampOpacity(translationX: drag.width, width: width)
        HStack {
            SwipeStamp(direction: .like).opacity(drag.width > 0 ? opacity : 0)
            Spacer()
            SwipeStamp(direction: .pass).opacity(drag.width < 0 ? opacity : 0)
        }
        .padding(Tokens.Space.xl)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func dragGesture(item: Item, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: Tokens.Gesture.dragMinimumDistance)
            .onChanged { value in
                guard !isCommitting else { return }
                drag = value.translation
                pastThreshold = physics.isPastThreshold(translationX: value.translation.width, width: size.width)
            }
            .onEnded { value in
                guard !isCommitting else { return }
                let outcome = physics.decide(translation: value.translation,
                                             predictedEndTranslation: value.predictedEndTranslation,
                                             velocity: value.velocity, cardSize: size)
                pastThreshold = false
                switch outcome {
                case .commit(let direction):
                    commit(direction, item: item, size: size)
                case .details:
                    withArtAnimation(ArtMotion.snapBack, reduceMotion: reduceMotion) { drag = .zero }
                    onDetails?(item)
                case .cancel:
                    withArtAnimation(ArtMotion.snapBack, reduceMotion: reduceMotion) { drag = .zero }
                }
            }
    }

    private func handle(_ command: CardStackController.Command?, size: CGSize) {
        switch command {
        case .swipe(let direction):
            if let top = items.first { commit(direction, item: top, size: size) }
        case .undo:
            restore(size: size)
        case nil:
            break
        }
    }

    private func commit(_ direction: SwipeDirection, item: Item, size: CGSize) {
        guard !isCommitting else { return }
        isCommitting = true
        commitCount &+= 1
        let finish = {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                onSwipe(item, direction)
                controller.didCommit(direction)
                drag = .zero
                fadingOut = false
                isCommitting = false
            }
        }
        if reduceMotion {
            withAnimation(ArtMotion.crossfade) { fadingOut = true } completion: { finish() }
        } else {
            let exitX = direction.sign * (size.width * 1.5)
            withAnimation(Tokens.Motion.Easing.exit(duration: Tokens.Motion.Duration.base)) {
                drag = CGSize(width: exitX, height: drag.height + size.height * 0.05)
            } completion: { finish() }
        }
    }

    private func restore(size: CGSize) {
        guard let onUndo, let direction = controller.lastDirection, !isCommitting else { return }
        var place = Transaction()
        place.disablesAnimations = true
        withTransaction(place) {
            onUndo()
            controller.didUndo()
            if reduceMotion {
                fadingOut = true
            } else {
                drag = CGSize(width: direction.sign * size.width * 1.5, height: 0)
            }
        }
        Task { @MainActor in
            await Task.yield()
            withArtAnimation(ArtMotion.snapBack, reduceMotion: reduceMotion) {
                drag = .zero
                fadingOut = false
            }
        }
    }
}

/// Adds the VoiceOver "Details" action when enabled.
private struct DetailsAction: ViewModifier {
    let enabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.accessibilityAction(named: Text("Details"), action)
        } else {
            content
        }
    }
}

/// KEEP / PASS stamp drawn on the moving card (icon + word, not colour alone).
struct SwipeStamp: View {
    let direction: SwipeDirection

    var body: some View {
        let isLike = direction == .like
        let color = isLike ? Tokens.Color.feedbackHit : Tokens.Color.textPrimary
        Label(isLike ? "KEEP" : "PASS", systemImage: isLike ? "heart.fill" : "xmark")
            .labelStyle(.titleAndIcon)
            .artTextStyle(Tokens.Typography.label)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, Tokens.Space.m)
            .padding(.vertical, Tokens.Space.xs)
            .background(Tokens.Color.bgCanvas.opacity(0.85),
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.control / 2, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.control / 2, style: .continuous)
                .stroke(color, lineWidth: Tokens.Space.xxs))
            .rotationEffect(.degrees(isLike ? -Tokens.Gesture.swipeMaxRotationDeg : Tokens.Gesture.swipeMaxRotationDeg))
    }
}

/// The required visible alternative to swiping: 64pt pass / like buttons and an optional undo.
public struct CardStackButtons: View {
    private let controller: CardStackController
    private let showsUndo: Bool

    /// Creates the button row.
    public init(controller: CardStackController, showsUndo: Bool = true) {
        self.controller = controller
        self.showsUndo = showsUndo
    }

    public var body: some View {
        HStack(spacing: Tokens.Space.xl) {
            roundButton("xmark", label: "Pass", color: Tokens.Color.textPrimary) { controller.swipe(.pass) }
            if showsUndo {
                Button { controller.undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(ArtFont.label)
                        .frame(width: Tokens.Size.minTarget, height: Tokens.Size.minTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.Color.textSecondary)
                .artGlass(Circle(), interactive: true)
                .disabled(!controller.canUndo)
                .opacity(controller.canUndo ? 1 : 0.4)
                .accessibilityLabel(Text("Undo"))
            }
            roundButton("heart.fill", label: "Like", color: Tokens.Color.feedbackHit) { controller.swipe(.like) }
        }
    }

    private func roundButton(_ symbol: String, label: String, color: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.medium))
                .frame(width: Tokens.Size.swipeButton, height: Tokens.Size.swipeButton)
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
        .artGlass(Circle(), interactive: true)
        .accessibilityLabel(Text(label))
    }
}
