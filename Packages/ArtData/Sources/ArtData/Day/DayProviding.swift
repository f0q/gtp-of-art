import ArtCore
import Foundation

/// Supplies "today" as a local calendar day for the daily challenge and streaks.
public protocol DayProviding: Sendable {
    /// The current local day.
    func today() -> DayKey
}

/// The device's local Gregorian date in a time zone (default `TimeZone.current`, read at each call
/// so travel is picked up). Uses `Calendar(identifier: .gregorian)`, never `Calendar.current`,
/// which may be Buddhist, Japanese, etc.
public struct SystemDayProvider: DayProviding {
    private let timeZone: TimeZone?
    private let now: @Sendable () -> Date

    /// - Parameters:
    ///   - timeZone: fixed zone, or nil for `TimeZone.current` at each call.
    ///   - now: clock (injectable for tests).
    public init(timeZone: TimeZone? = nil, now: @escaping @Sendable () -> Date = { Date() }) {
        self.timeZone = timeZone
        self.now = now
    }

    public func today() -> DayKey {
        Self.dayKey(for: now(), in: timeZone ?? .current)
    }

    /// The start of the next local day after now (when the app should recompute the daily).
    public func nextDayStart() -> Date {
        Self.nextDayStart(after: now(), in: timeZone ?? .current)
    }

    /// The Gregorian calendar fixed to a time zone.
    public static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// The local calendar date of `date` in `timeZone`.
    public static func dayKey(for date: Date, in timeZone: TimeZone) -> DayKey {
        let c = calendar(in: timeZone).dateComponents([.year, .month, .day], from: date)
        return DayKey(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    /// The first instant of the local day following `date` (handles DST days of 23/25 hours).
    public static func nextDayStart(after date: Date, in timeZone: TimeZone) -> Date {
        let cal = calendar(in: timeZone)
        let start = cal.startOfDay(for: date)
        return cal.date(byAdding: .day, value: 1, to: start) ?? date.addingTimeInterval(86_400)
    }
}

/// Always returns the same day (tests, previews, UI tests launched with `-fixedDay`).
public struct FixedDayProvider: DayProviding {
    public let dayKey: DayKey

    public init(dayKey: DayKey) {
        self.dayKey = dayKey
    }

    public func today() -> DayKey { dayKey }
}
