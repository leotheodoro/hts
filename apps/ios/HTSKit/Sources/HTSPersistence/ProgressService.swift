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
