import Foundation
import GRDB

/// Storage conventions shared by every table (docs/decisions/0009):
/// UUIDs as lowercase text and dates as UTC ISO 8601 text with milliseconds ("2026-10-28T13:31:00.123Z").
///
/// GRDB resolves these strategies through its own default implementations, so a protocol extension cannot
/// override them. Each record forwards to these values instead (see `Athlete`).
enum Storage {
    static let uuidEncoding: DatabaseUUIDEncodingStrategy = .lowercaseString
    static let dateEncoding: DatabaseDateEncodingStrategy = .custom { ISO8601Millis.format($0) }
    static let dateDecoding: DatabaseDateDecodingStrategy = .custom { value in
        String.fromDatabaseValue(value).flatMap(ISO8601Millis.parse)
    }
}

/// ISO 8601 with milliseconds, going through integer milliseconds so a date survives the round trip exactly.
enum ISO8601Millis {
    private static let seconds = Date.ISO8601FormatStyle()

    static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    static func date(milliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }

    static func format(_ date: Date) -> String {
        let ms = milliseconds(date)
        let (whole, fraction) = ms.quotientAndRemainder(dividingBy: 1000)
        let (secs, millis) = fraction < 0 ? (whole - 1, fraction + 1000) : (whole, fraction)
        let base = seconds.format(Date(timeIntervalSince1970: Double(secs)))
        return base.dropLast() + "." + String(format: "%03lld", millis) + "Z"
    }

    static func parse(_ text: String) -> Date? {
        guard text.hasSuffix("Z") else { return nil }
        let parts = text.dropLast().split(separator: ".", maxSplits: 1)
        guard let head = parts.first, let base = try? seconds.parse(head + "Z") else { return nil }
        var millis: Int64 = 0
        if parts.count == 2 {
            let digits = parts[1].prefix(3).padding(toLength: 3, withPad: "0", startingAt: 0)
            guard let value = Int64(digits) else { return nil }
            millis = value
        }
        return date(milliseconds: Int64(base.timeIntervalSince1970) * 1000 + millis)
    }
}

extension Date {
    /// Dates are stored with millisecond precision; round before saving so a record equals its stored copy.
    public var roundedToMilliseconds: Date {
        ISO8601Millis.date(milliseconds: ISO8601Millis.milliseconds(self))
    }
}
