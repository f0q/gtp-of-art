import SwiftUI

// The system's Reduce Motion / Reduce Transparency environment values are read-only, so previews,
// snapshot tests and UI tests cannot force them. Components read these wrappers instead, which
// return the system value unless an override is set.

private struct ReduceMotionOverrideKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

private struct ReduceTransparencyOverrideKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    /// Forces Reduce Motion on/off for this subtree (previews, snapshots). `nil` = follow the system.
    public var artReduceMotionOverride: Bool? {
        get { self[ReduceMotionOverrideKey.self] }
        set { self[ReduceMotionOverrideKey.self] = newValue }
    }

    /// Forces Reduce Transparency on/off for this subtree. `nil` = follow the system.
    public var artReduceTransparencyOverride: Bool? {
        get { self[ReduceTransparencyOverrideKey.self] }
        set { self[ReduceTransparencyOverrideKey.self] = newValue }
    }

    /// Effective Reduce Motion: the override, else the system setting.
    public var artReduceMotion: Bool { artReduceMotionOverride ?? accessibilityReduceMotion }

    /// Effective Reduce Transparency: the override, else the system setting.
    public var artReduceTransparency: Bool { artReduceTransparencyOverride ?? accessibilityReduceTransparency }
}
