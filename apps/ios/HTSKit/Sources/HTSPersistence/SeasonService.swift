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

    /// Makes `seasonId` the active season. The previous one pauses on its current arc, whose count restarts
    /// (#204, docs/decisions/0034): it becomes current again from zero when that season is reactivated. The new
    /// season continues from its first arc not completed.
    public func activate(seasonId: UUID, athleteId: UUID, now: Date = .now) async throws {
        try await database.writer.write { db in
            // Already active with a current arc: nothing to do, and the arc keeps its start date (#220).
            let alreadyCurrent = try Bool.fetchOne(
                db,
                sql: """
                    SELECT EXISTS (SELECT 1 FROM season s JOIN arc a ON a.season_id = s.id
                    WHERE s.id = ? AND s.active AND a.status = 'current' AND a.deleted_at IS NULL)
                    """, arguments: [seasonId.sql])
            if alreadyCurrent == true { return }
            let stamp = ISO8601Millis.format(now)
            try db.execute(
                sql: """
                    UPDATE arc SET count_reset_at = ?, updated_at = ?
                    WHERE athlete_id = ? AND status = 'current' AND kind != 'filler' AND deleted_at IS NULL
                    AND season_id IS NOT NULL AND season_id != ?;
                    UPDATE arc SET status = 'queued', updated_at = ?
                    WHERE athlete_id = ? AND status = 'current' AND deleted_at IS NULL;
                    UPDATE season SET active = 0, updated_at = ?
                    WHERE athlete_id = ? AND active AND id != ? AND deleted_at IS NULL;
                    UPDATE season SET active = 1, updated_at = ? WHERE id = ? AND NOT active;
                    """,
                arguments: [
                    stamp, stamp, athleteId.sql, seasonId.sql, stamp, athleteId.sql, stamp, athleteId.sql, seasonId.sql,
                    stamp, seasonId.sql,
                ])
            try Self.promoteNextArc(seasonId: seasonId, now: now, db)
        }
    }

    /// "Desativar temporada" (#214, docs/decisions/0036): no season stays active. The current arc goes back to the
    /// queue with its count restarted, as in a switch (docs/decisions/0034); activating the season again continues
    /// from it.
    public func deactivate(seasonId: UUID, athleteId: UUID, now: Date = .now) async throws {
        try await database.writer.write { db in
            let stamp = ISO8601Millis.format(now)
            try db.execute(
                sql: """
                    UPDATE arc SET count_reset_at = ?, status = 'queued', updated_at = ?
                    WHERE athlete_id = ? AND season_id = ? AND status = 'current' AND deleted_at IS NULL;
                    UPDATE season SET active = 0, updated_at = ? WHERE id = ? AND active;
                    """,
                arguments: [stamp, stamp, athleteId.sql, seasonId.sql, stamp, seasonId.sql])
        }
    }

    /// An arc made current before #220 kept the start date of the plan import, so it showed as ATRASADO right
    /// away. The current arc of the active season starts on the Monday after the last workout of its completed
    /// arcs. Run when the app shows the plan; nothing changes once the start date is after that workout.
    public func alignStartDate(athleteId: UUID, now: Date = .now) async throws {
        try await database.writer.write { db in
            guard
                var arc = try Arc.filter(Columns.athleteId == athleteId.sql).filter(Column("status") == "current")
                    .filter(Column("kind") != ArcKind.filler.rawValue).filter(Column("weeks") != nil)
                    .filter(Columns.deletedAt == nil).fetchOne(db),
                let seasonId = arc.seasonId,
                let last = try String.fetchOne(
                    db,
                    sql: """
                        SELECT MAX(s.started_at) FROM session s JOIN arc a ON a.id = s.arc_id
                        WHERE a.season_id = ? AND a.status = 'completed' AND a.deleted_at IS NULL
                        AND s.status = 'completed' AND s.deleted_at IS NULL
                        """, arguments: [seasonId.sql]
                ).flatMap(ISO8601Millis.parse)
            else { return }
            let start = LocalDate(last, in: .current).nextMonday
            if let current = arc.startDate, current >= start { return }
            arc.startDate = start
            arc.updatedAt = now.roundedToMilliseconds
            try arc.update(db)
        }
    }

    /// In a season past its initial arcs, the current arc follows the calendar month (#210). Run when the app
    /// shows the plan; nothing changes outside the monthly phase or when the right arc is already current.
    public func alignMonthlyArc(athleteId: UUID, now: Date = .now) async throws {
        try await database.writer.write { db in
            guard
                let seasonId = try String.fetchOne(
                    db, sql: "SELECT id FROM season WHERE athlete_id = ? AND active AND deleted_at IS NULL",
                    arguments: [athleteId.sql]
                ).flatMap(UUID.init(uuidString:))
            else { return }
            let arcs = try Self.liveArcs(seasonId: seasonId, db)
            guard let target = MonthlyArcs.current(in: arcs, month: Self.month(of: now)), target.status != .current
            else { return }
            try Self.makeCurrent(target, among: arcs, now: now, db)
        }
    }

    /// The arc that comes next in the season, made current: the first open initial arc in order, or in the
    /// monthly phase the month of the calendar (#210). Returns it, or nil when the season has nothing left.
    @discardableResult
    static func promoteNextArc(seasonId: UUID, now: Date, _ db: Database) throws -> Arc? {
        let arcs = try liveArcs(seasonId: seasonId, db)
        let next =
            MonthlyArcs.inMonthlyPhase(arcs)
            ? MonthlyArcs.current(in: arcs, month: month(of: now))
            : arcs.first { $0.status == .queued && $0.kind != .filler && !$0.isMonthly }
        guard let next, next.status != .current else { return nil }
        return try makeCurrent(next, among: arcs, now: now, db)
    }

    @discardableResult
    private static func makeCurrent(_ arc: Arc, among arcs: [Arc], now: Date, _ db: Database) throws -> Arc {
        let stamp = now.roundedToMilliseconds
        // One current arc per athlete: the one it replaces goes back to waiting first.
        for var other in arcs where other.status == .current && other.id != arc.id {
            other.status = .queued
            other.updatedAt = stamp
            try other.update(db)
        }
        var arc = arc
        arc.status = .current
        // The weeks of the arc start on the Monday after the previous one ends (#220).
        if arc.weeks != nil { arc.startDate = LocalDate(now, in: .current).nextMonday }
        arc.updatedAt = stamp
        try arc.update(db)
        return arc
    }

    private static func liveArcs(seasonId: UUID, _ db: Database) throws -> [Arc] {
        try Arc.filter(Column("season_id") == seasonId.sql).filter(Columns.deletedAt == nil)
            .order(Columns.position).fetchAll(db)
    }

    static func month(of date: Date) -> Int { Calendar.current.component(.month, from: date) }
}
