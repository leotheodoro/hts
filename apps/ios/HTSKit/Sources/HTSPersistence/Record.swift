import Foundation
import GRDB
import HTSDomain

/// Storage conventions shared by every table (docs/decisions/0009): snake_case columns, UUIDs as lowercase text,
/// dates as UTC ISO 8601 text with milliseconds ("2026-10-28T13:31:00.123Z"), nested values as JSON text.
///
/// The strategy requirements are redeclared here on purpose: without that, Swift binds GRDB's own default
/// implementations and ignores the ones in this extension.
public protocol HTSRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static func databaseUUIDEncodingStrategy(for column: String) -> DatabaseUUIDEncodingStrategy
    static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy
    static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { get }
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { get }
}

extension HTSRecord {
    public static func databaseUUIDEncodingStrategy(for column: String) -> DatabaseUUIDEncodingStrategy {
        .lowercaseString
    }

    public static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy {
        .custom { ISO8601Millis.format($0) }
    }

    public static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy {
        .custom { value in String.fromDatabaseValue(value).flatMap(ISO8601Millis.parse) }
    }

    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
}

/// ISO 8601 with milliseconds, going through integer milliseconds so a date survives the round trip exactly.
enum ISO8601Millis {
    private static let seconds = Date.ISO8601FormatStyle()

    static func format(_ date: Date) -> String {
        let ms = Int64((date.timeIntervalSince1970 * 1000).rounded())
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
        return Date(timeIntervalSince1970: Double(Int64(base.timeIntervalSince1970) * 1000 + millis) / 1000)
    }
}

extension LocalDate: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue { description.databaseValue }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> LocalDate? {
        String.fromDatabaseValue(dbValue).flatMap(LocalDate.init)
    }
}

extension UUID {
    /// How ids are stored (lowercase text). Use it in query filters: GRDB would otherwise bind a UUID as a 16-byte
    /// blob, which never matches.
    var sql: String { uuidString.lowercased() }
}
