import Foundation
import GRDB
import HTSDomain

/// Root of all user data, so it has no `athlete_id` of its own.
public struct Athlete: HTSRecord, Identifiable, Hashable {
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
}

/// Columns used in queries. Names follow the snake_case convention of every table.
enum Columns {
    static let id = Column("id")
    static let athleteId = Column("athlete_id")
    static let createdAt = Column("created_at")
    static let deletedAt = Column("deleted_at")
    static let position = Column("position")
}
