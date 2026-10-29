import Foundation
import GRDB
import HTSDomain

/// Temporadas: named sequences of arcs. One is active at a time; inside it, the first arc not completed is the
/// current one and the next ones wait (docs/decisions/0029).
public struct SeasonService: Sendable {
    private let database: AppDatabase

    public init(_ database: AppDatabase) {
        self.database = database
    }

    /// Live seasons, active first, then by position.
    public func seasons(athleteId: UUID) async throws -> [Season] {
        try await database.writer.read { db in
            try Season.filter(Columns.athleteId == athleteId.sql).filter(Columns.deletedAt == nil)
                .order(Column("active").desc, Columns.position).fetchAll(db)
        }
    }

    public func activeSeason(athleteId: UUID) async throws -> Season? {
        try await database.writer.read { db in
            try Season.filter(Columns.athleteId == athleteId.sql).filter(Column("active") == true)
                .filter(Columns.deletedAt == nil).fetchOne(db)
        }
    }

    /// The live season with this name, or a new one at the end. The first season of an athlete starts active.
    public func season(named name: String, athleteId: UUID, now: Date = .now) async throws -> Season {
        try await database.writer.write { db in
            let live = Season.filter(Columns.athleteId == athleteId.sql).filter(Columns.deletedAt == nil)
            if let existing = try live.filter(Column("name") == name).fetchOne(db) { return existing }
            let position =
                (try Int.fetchOne(
                    db, sql: "SELECT MAX(position) FROM season WHERE athlete_id = ? AND deleted_at IS NULL",
                    arguments: [athleteId.sql]) ?? -1) + 1
            let hasActive = try live.filter(Column("active") == true).fetchCount(db) > 0
            let season = Season(
                id: UUIDv7.make(at: now), athleteId: athleteId, name: name, position: position, active: !hasActive,
                createdAt: now)
            try season.insert(db)
            return season
        }
    }

    /// Makes `seasonId` the active season. The previous one pauses on its current arc (it becomes current again
    /// when that season is reactivated); the new one continues from its first arc not completed.
    public func activate(seasonId: UUID, athleteId: UUID, now: Date = .now) async throws {
        try await database.writer.write { db in
            let stamp = ISO8601Millis.format(now)
            try db.execute(
                sql: """
                    UPDATE arc SET status = 'queued', updated_at = ?
                    WHERE athlete_id = ? AND status = 'current' AND deleted_at IS NULL;
                    UPDATE season SET active = 0, updated_at = ?
                    WHERE athlete_id = ? AND active AND id != ? AND deleted_at IS NULL;
                    UPDATE season SET active = 1, updated_at = ? WHERE id = ? AND NOT active;
                    """,
                arguments: [stamp, athleteId.sql, stamp, athleteId.sql, seasonId.sql, stamp, seasonId.sql])
            try Self.promoteFirstOpenArc(seasonId: seasonId, stamp: stamp, db)
        }
    }

    /// The first arc of the season that is not completed (and not Manutenção) becomes current.
    static func promoteFirstOpenArc(seasonId: UUID, stamp: String, _ db: Database) throws {
        try db.execute(
            sql: """
                UPDATE arc SET status = 'current', updated_at = ?
                WHERE id = (
                    SELECT id FROM arc WHERE season_id = ? AND status = 'queued' AND kind != 'filler'
                    AND deleted_at IS NULL ORDER BY position LIMIT 1)
                """, arguments: [stamp, seasonId.sql])
    }
}
