import Foundation
import GRDB
import HTSDomain

/// Activities that reached the athlete from other platforms (Garmin), read-only on the device (docs/decisions/0033).
public struct ActivityRepository: Sendable {
    private let database: AppDatabase

    public init(_ database: AppDatabase) {
        self.database = database
    }

    /// Not deleted, oldest first.
    public func activities(athleteId: UUID) async throws -> [ImportedActivity] {
        try await database.writer.read { try Self.activities(athleteId: athleteId, $0) }
    }

    static func activities(athleteId: UUID, _ db: Database) throws -> [ImportedActivity] {
        try ImportedActivity.filter(Columns.athleteId == athleteId.sql)
            .filter(Columns.deletedAt == nil)
            .order(Column("started_at"))
            .fetchAll(db)
    }
}
