import Foundation
import GRDB
import HTSDomain

public struct BattleRepository: Sendable {
    private let database: AppDatabase

    public init(_ database: AppDatabase) {
        self.database = database
    }

    /// The next competition from `today` on, or the latest one without a result yet.
    public func current(athleteId: UUID, today: LocalDate) async throws -> Battle? {
        try await database.writer.read { db in
            let live = Battle.filter(Columns.athleteId == athleteId.sql).filter(Columns.deletedAt == nil)
            if let upcoming = try live.filter(Column("date") >= today.description).order(Column("date")).fetchOne(db) {
                return upcoming
            }
            return try live.filter(Column("result") == nil).order(Column("date").desc).fetchOne(db)
        }
    }

    public func save(_ battle: Battle, now: Date = .now) async throws {
        var battle = battle
        battle.updatedAt = now.roundedToMilliseconds
        try await database.writer.write { [battle] db in try battle.save(db) }
    }
}
