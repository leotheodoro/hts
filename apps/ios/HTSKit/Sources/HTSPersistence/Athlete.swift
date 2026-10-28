import Foundation
import GRDB

/// Root of all user data, so it has no `athlete_id` of its own.
public struct Athlete: Codable, FetchableRecord, PersistableRecord, Sendable, Identifiable, Hashable {
    public static let databaseTableName = "athlete"
    public static let defaultRestSeconds = 90

    public var id: UUID
    public var displayName: String
    public var defaultRestSeconds: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUIDv7.make(), displayName: String, defaultRestSeconds: Int = Athlete.defaultRestSeconds,
        createdAt: Date = .now, updatedAt: Date? = nil, deletedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.defaultRestSeconds = defaultRestSeconds
        self.createdAt = createdAt.roundedToMilliseconds
        self.updatedAt = (updatedAt ?? createdAt).roundedToMilliseconds
        self.deletedAt = deletedAt?.roundedToMilliseconds
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case defaultRestSeconds = "default_rest_seconds"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    public enum Columns {
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let deletedAt = Column(CodingKeys.deletedAt)
    }
}

extension Athlete {
    public static func databaseUUIDEncodingStrategy(for column: String) -> DatabaseUUIDEncodingStrategy {
        Storage.uuidEncoding
    }

    public static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy {
        Storage.dateEncoding
    }

    public static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy {
        Storage.dateDecoding
    }
}
