/// A proleptic-Gregorian calendar date with no time zone, used for the daily challenge and streaks.
///
/// The app derives it from the device's *local* Gregorian date. Encodes as `"yyyy-MM-dd"`.
public struct DayKey: Sendable, Hashable, Comparable, Codable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    /// Creates a key. Use `isValid` to check that the date exists.
    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Creates the key for a day number (days since 1970-01-01; Hinnant `civil_from_days`).
    public init(dayNumber: Int) {
        let z = dayNumber + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        let y = yoe + era * 400 + (m <= 2 ? 1 : 0)
        self.init(year: y, month: m, day: d)
    }

    /// Parses `"yyyy-MM-dd"` (exactly 4-2-2 ASCII digits). Returns nil if malformed or not a real date.
    public init?(string: String) {
        let bytes = Array(string.utf8)
        guard bytes.count == 10, bytes[4] == 0x2D, bytes[7] == 0x2D else { return nil }
        func number(_ range: Range<Int>) -> Int? {
            var value = 0
            for i in range {
                let b = bytes[i]
                guard b >= 0x30, b <= 0x39 else { return nil }
                value = value * 10 + Int(b - 0x30)
            }
            return value
        }
        guard let y = number(0..<4), let m = number(5..<7), let d = number(8..<10) else { return nil }
        self.init(year: y, month: m, day: d)
        guard isValid else { return nil }
    }

    /// Days since 1970-01-01 (Hinnant `days_from_civil`); negative before the epoch.
    public var dayNumber: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = month > 2 ? month - 3 : month + 9
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    /// True for leap years in the proleptic Gregorian calendar.
    public static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    /// Number of days in `month` of `year`.
    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 0
        }
    }

    /// True if the date exists and the year is in 1...9999 (so it formats as 4 digits).
    public var isValid: Bool {
        (1...9999).contains(year) && (1...12).contains(month)
            && day >= 1 && day <= Self.daysInMonth(year: year, month: month)
    }

    /// The key `days` days later (negative for earlier).
    public func adding(days: Int) -> DayKey {
        DayKey(dayNumber: dayNumber + days)
    }

    /// `"yyyy-MM-dd"`, zero-padded (year to 4 digits, month and day to 2).
    public var isoString: String {
        Self.pad(year, 4) + "-" + Self.pad(month, 2) + "-" + Self.pad(day, 2)
    }

    public var description: String { isoString }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        lhs.dayNumber < rhs.dayNumber
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let key = DayKey(string: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid DayKey \(text)")
        }
        self = key
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isoString)
    }

    static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(value < 0 ? -value : value)
        let padding = String(repeating: "0", count: max(0, width - digits.count))
        return (value < 0 ? "-" : "") + padding + digits
    }
}
