import Foundation

/// A calendar date without time or time zone ("2026-11-02"), like Postgres `date`.
public struct LocalDate: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        var components = DateComponents(year: year, month: month, day: day)
        components.calendar = Self.calendar
        guard components.isValidDate else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    public init?(_ text: String) {
        let parts = text.split(separator: "-")
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The calendar day of `date` in `timeZone` (the athlete's device time zone).
    public init(_ date: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = c.year!
        self.month = c.month!
        self.day = c.day!
    }

    /// The date `days` later (or earlier, when negative).
    public func adding(days: Int) -> LocalDate {
        let start = Self.calendar.date(from: DateComponents(year: year, month: month, day: day))!
        return LocalDate(Self.calendar.date(byAdding: .day, value: days, to: start)!, in: Self.calendar.timeZone)
    }

    /// Monday of the week (weeks run Monday to Sunday, as in the weekly goal).
    public var weekStart: LocalDate {
        let date = Self.calendar.date(from: DateComponents(year: year, month: month, day: day))!
        let weekday = Self.calendar.component(.weekday, from: date)  // 1 = Sunday … 7 = Saturday
        return adding(days: -((weekday + 5) % 7))
    }

    public var weekEnd: LocalDate { weekStart.adding(days: 6) }

    /// Whole days from `self` to `other`.
    public func days(to other: LocalDate) -> Int {
        let from = Self.calendar.date(from: DateComponents(year: year, month: month, day: day))!
        let to = Self.calendar.date(from: DateComponents(year: other.year, month: other.month, day: other.day))!
        return Self.calendar.dateComponents([.day], from: from, to: to).day!
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let date = LocalDate(text) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid date \(text)"))
        }
        self = date
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    /// Gregorian, UTC: only used to validate and do day arithmetic, never to read the clock.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}

extension Date {
    /// Timestamps have millisecond precision in SQLite and in the API; round before saving so a record equals its
    /// stored copy.
    public var roundedToMilliseconds: Date {
        Date(timeIntervalSince1970: Double(Int64((timeIntervalSince1970 * 1000).rounded())) / 1000)
    }
}
