import SwiftUI

#if ART_SWIFTUI_MACROS
extension EnvironmentValues {
    /// Whether semantic haptics play. The app binds this to the Settings "Haptics" toggle at the root.
    @Entry public var hapticsEnabled: Bool = true
}
#else
// Command Line Tools build (no SwiftUI macro plugin): the hand-written equivalent of `@Entry`.
private struct HapticsEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    /// Whether semantic haptics play. The app binds this to the Settings "Haptics" toggle at the root.
    public var hapticsEnabled: Bool {
        get { self[HapticsEnabledKey.self] }
        set { self[HapticsEnabledKey.self] = newValue }
    }
}
#endif

extension View {
    /// Plays a semantic haptic token when `trigger` changes, unless haptics are disabled in Settings.
    ///
    /// Wraps `sensoryFeedback(trigger:_:)`; the system additionally respects the device's own
    /// "System Haptics" setting.
    public func artHaptic<T: Equatable>(_ token: Tokens.Haptic, trigger: T) -> some View {
        modifier(ArtHapticModifier(token: token, trigger: trigger, condition: nil))
    }

    /// Plays a semantic haptic token when `trigger` changes and `condition(old, new)` is true.
    public func artHaptic<T: Equatable>(_ token: Tokens.Haptic, trigger: T,
                                        condition: @escaping (T, T) -> Bool) -> some View {
        modifier(ArtHapticModifier(token: token, trigger: trigger, condition: condition))
    }
}

/// Implementation of `artHaptic(_:trigger:)`.
struct ArtHapticModifier<T: Equatable>: ViewModifier {
    let token: Tokens.Haptic
    let trigger: T
    let condition: ((T, T) -> Bool)?
    @Environment(\.hapticsEnabled) private var enabled

    func body(content: Content) -> some View {
        let feedback = token.sensoryFeedback
        let enabled = enabled
        let condition = condition
        return content.sensoryFeedback(trigger: trigger) { old, new in
            guard enabled else { return nil }
            if let condition, !condition(old, new) { return nil }
            return feedback
        }
    }
}
