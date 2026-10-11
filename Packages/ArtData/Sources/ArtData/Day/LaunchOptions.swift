import ArtCore

/// Test hooks passed as launch arguments: `-uiTesting -fixedDay 2026-10-11 -resetState`.
public struct LaunchOptions: Sendable, Equatable {
    /// `-uiTesting`: use in-memory stores and disable animations where the app chooses to.
    public var uiTesting: Bool
    /// `-fixedDay yyyy-MM-dd`: pin "today" (nil if absent or malformed).
    public var fixedDay: DayKey?
    /// `-resetState`: wipe the profile and settings on launch.
    public var resetState: Bool

    public init(uiTesting: Bool = false, fixedDay: DayKey? = nil, resetState: Bool = false) {
        self.uiTesting = uiTesting
        self.fixedDay = fixedDay
        self.resetState = resetState
    }

    /// Parses process arguments (e.g. `ProcessInfo.processInfo.arguments`).
    public init(arguments: [String]) {
        self.init(
            uiTesting: arguments.contains("-uiTesting"),
            fixedDay: Self.fixedDay(in: arguments),
            resetState: arguments.contains("-resetState"))
    }

    /// The value after the last `-fixedDay`, if it is a valid `yyyy-MM-dd` date.
    public static func fixedDay(in arguments: [String]) -> DayKey? {
        guard let i = arguments.lastIndex(of: "-fixedDay"), i + 1 < arguments.count else { return nil }
        return DayKey(string: arguments[i + 1])
    }

    /// `FixedDayProvider` when `-fixedDay` was given, else `SystemDayProvider()`.
    public var dayProvider: any DayProviding {
        if let fixedDay { return FixedDayProvider(dayKey: fixedDay) }
        return SystemDayProvider()
    }
}
