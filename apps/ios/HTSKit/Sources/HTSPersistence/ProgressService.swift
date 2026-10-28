import Foundation
import GRDB
import HTSDomain

/// Derived progress (XP, level, rank, records, volume) computed from the records every time
/// (docs/decisions/0010). Deleting a session simply drops it from the history.
public struct ProgressService: Sendable {
    /// What the "Treino concluído" screen shows.
    public struct Completion: Hashable, Sendable {
        public let session: Session
        public let progress: SessionProgress
        public let before: ProgressHistory
        public let after: ProgressHistory
        /// Names of the exercises with a new limit, in order.
        public let recordNames: [String]

        public var leveledUp: Bool { after.level > before.level }
        public var rankedUp: Bool { after.rank.id != before.rank.id }
    }

    private let database: AppDatabase
    private let progression: Progression

    public init(_ database: AppDatabase, progression: Progression = Progression()) {
        self.database = database
        self.progression = progression
    }

    /// Completed live sessions in chronological order, with their sets as progress sees them.
    public func history(athleteId: UUID) async throws -> (sessions: [Session], history: ProgressHistory) {
        try await database.writer.read { db in
            let sessions = try Self.completedSessions(athleteId: athleteId, db)
            return (sessions, progression.history(try sessions.map { try Self.historySets($0, db) }))
        }
    }

    public func completion(sessionId: UUID) async throws -> Completion? {
        try await database.writer.read { db in
            guard let session = try Session.filter(key: sessionId).fetchOne(db) else { return nil }
            let sessions = try Self.completedSessions(athleteId: session.athleteId, db)
            guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return nil }
            let sets = try sessions.map { try Self.historySets($0, db) }
            let after = progression.history(Array(sets[...index]))
            let before = progression.history(Array(sets[..<index]))
            let progress = after.sessions[index]
            let names = Dictionary(
                session.planSnapshot.blocks.flatMap(\.exercises).map { ($0.exerciseId.sql, $0.name) },
                uniquingKeysWith: { first, _ in first })
            return Completion(
                session: session, progress: progress, before: before, after: after,
                recordNames: progress.records.compactMap { names[$0] })
        }
    }

    /// Weekly streak from completed sessions; the goal of each session is its arc's template count, nil for filler.
    public func streak(athleteId: UUID, today: LocalDate) async throws -> Streak {
        try await database.writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT s.local_date, a.kind,
                        (SELECT COUNT(*) FROM workout_template t WHERE t.arc_id = a.id AND t.deleted_at IS NULL) AS goal
                    FROM session s JOIN arc a ON a.id = s.arc_id
                    WHERE s.athlete_id = ? AND s.status = 'completed' AND s.deleted_at IS NULL
                    """, arguments: [athleteId.sql])
            let sessions = rows.compactMap { row -> StreakSession? in
                guard let date = LocalDate(row["local_date"] as String) else { return nil }
                let filler = (row["kind"] as String) == ArcKind.filler.rawValue
                return StreakSession(localDate: date, weeklyGoal: filler ? nil : row["goal"])
            }
            return progression.streak(sessions, today: today)
        }
    }

    /// Best load per catalog exercise over completed live sessions: the first set that reached it.
    public struct Record: Hashable, Sendable, Identifiable {
        public let exerciseId: UUID
        public let exerciseName: String
        public let weightKg: Decimal
        public let reps: Int?
        public let sessionId: UUID
        public let date: LocalDate
        public var id: UUID { exerciseId }
    }

    public func records(athleteId: UUID) async throws -> [Record] {
        try await database.writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT s.exercise_id, e.name, s.weight_kg, s.reps, s.session_id, x.local_date
                    FROM logged_set s
                    JOIN session x ON x.id = s.session_id
                    JOIN exercise e ON e.id = s.exercise_id
                    WHERE s.athlete_id = ? AND s.completed = 1 AND s.deleted_at IS NULL AND s.weight_kg IS NOT NULL
                    AND x.status = 'completed' AND x.deleted_at IS NULL
                    ORDER BY x.started_at, s.created_at
                    """, arguments: [athleteId.sql])
            var best: [String: Record] = [:]
            var order: [String] = []
            for row in rows {
                let exerciseId: String = row[0]
                guard let weight = Decimal.fromDatabaseValue(row[2]), let id = UUID(uuidString: exerciseId),
                    let sessionId = UUID(uuidString: row[4]), let date = LocalDate(row[5] as String)
                else { continue }
                if let current = best[exerciseId], current.weightKg >= weight { continue }
                if best[exerciseId] == nil { order.append(exerciseId) }
                best[exerciseId] = Record(
                    exerciseId: id, exerciseName: row[1], weightKg: weight, reps: row[3], sessionId: sessionId,
                    date: date)
            }
            return order.compactMap { best[$0] }.sorted { $0.exerciseName < $1.exerciseName }
        }
    }

    private static func completedSessions(athleteId: UUID, _ db: Database) throws -> [Session] {
        try Session.filter(Columns.athleteId == athleteId.sql)
            .filter(Column("status") == SessionStatus.completed.rawValue)
            .filter(Columns.deletedAt == nil)
            .order(Column("started_at"))
            .fetchAll(db)
    }

    private static func historySets(_ session: Session, _ db: Database) throws -> [HistorySet] {
        let units = Dictionary(
            session.planSnapshot.blocks.flatMap(\.exercises).map { ($0.exerciseId, $0.unit) },
            uniquingKeysWith: { first, _ in first })
        return try LoggedSet.filter(Column("session_id") == session.id.sql).filter(Columns.deletedAt == nil)
            .order(Column("created_at"), Column("set_number"))
            .fetchAll(db)
            .map {
                HistorySet(
                    exerciseId: $0.exerciseId.sql, unit: units[$0.exerciseId] ?? .reps, completed: $0.completed,
                    weightKg: $0.weightKg, reps: $0.reps)
            }
    }
}
