import Foundation
import GRDB
import HTSDomain

/// Reads and writes the record side: sessions, logged sets and fight rounds.
public struct SessionRepository: Sendable {
    /// Position of a session among the athlete's live sessions, ordered by start ("Treino 5 de 6").
    public struct Number: Hashable, Sendable {
        /// Across every arc (TR 13).
        public let global: Int
        /// Inside its arc, counting only sessions after the arc's last "Recomeçar contagem".
        public let inArc: Int
    }

    private let database: AppDatabase

    public init(_ database: AppDatabase) {
        self.database = database
    }

    /// Starts a session from the current plan, freezing it in the snapshot. Fails if another one is in progress.
    public func start(
        _ plan: TemplatePlan, now: Date = .now, timeZone: TimeZone = .current
    ) async throws -> Session {
        let session = Session(
            id: UUIDv7.make(at: now), athleteId: plan.template.athleteId, arcId: plan.template.arcId,
            planSnapshot: PlanSnapshot(plan), startedAt: now, timeZone: timeZone)
        try await database.writer.write { db in
            try session.insert(db)
            // One row per minimum set, so every field edit is an update of a row that already exists.
            for block in session.planSnapshot.blocks where block.kind != .fightRound {
                for exercise in block.exercises {
                    for number in 1...max(exercise.setsMin, 1) {
                        try LoggedSet(
                            id: UUIDv7.make(at: now), athleteId: session.athleteId, sessionId: session.id,
                            prescribedExerciseId: exercise.prescribedExerciseId, exerciseId: exercise.exerciseId,
                            setNumber: number, createdAt: now
                        ).insert(db)
                    }
                }
            }
        }
        return session
    }

    /// Adds a set after the last one of that exercise, for this session only.
    public func addSet(
        to session: Session, exercise: PlanSnapshot.Exercise, now: Date = .now
    ) async throws -> LoggedSet {
        try await database.writer.write { db in
            let last =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT MAX(set_number) FROM logged_set
                        WHERE session_id = ? AND prescribed_exercise_id = ? AND deleted_at IS NULL
                        """, arguments: [session.id.sql, exercise.prescribedExerciseId.sql]) ?? 0
            let set = LoggedSet(
                id: UUIDv7.make(at: now), athleteId: session.athleteId, sessionId: session.id,
                prescribedExerciseId: exercise.prescribedExerciseId, exerciseId: exercise.exerciseId,
                setNumber: last + 1, createdAt: now)
            try set.insert(db)
            return set
        }
    }

    /// "Anterior": completed sets of the last completed session of the same workout template, by catalog exercise
    /// and set number.
    public func previousSets(for session: Session) async throws -> [UUID: [Int: LoggedSet]] {
        try await database.writer.read { db in
            let sameTemplate = Column("workout_template_id") == session.workoutTemplateId.sql
            let completed = Column("status") == SessionStatus.completed.rawValue
            let earlier = Column("started_at") < ISO8601Millis.format(session.startedAt)
            guard
                let previous = try Session.filter(sameTemplate).filter(completed).filter(earlier)
                    .filter(Columns.deletedAt == nil)
                    .order(Column("started_at").desc).fetchOne(db)
            else { return [:] }
            let sets = try LoggedSet.filter(Column("session_id") == previous.id.sql)
                .filter(Column("completed") == true).filter(Columns.deletedAt == nil)
                .fetchAll(db)
            return Dictionary(grouping: sets, by: \.exerciseId).mapValues { sets in
                Dictionary(sets.map { ($0.setNumber, $0) }, uniquingKeysWith: { first, _ in first })
            }
        }
    }

    /// Completed live sessions whose local date falls between `from` and `to`, inclusive.
    public func completedCount(athleteId: UUID, from: LocalDate, to: LocalDate) async throws -> Int {
        try await database.writer.read { db in
            try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM session
                    WHERE athlete_id = ? AND status = 'completed' AND deleted_at IS NULL
                    AND local_date BETWEEN ? AND ?
                    """, arguments: [athleteId.sql, from.description, to.description]) ?? 0
        }
    }

    /// Letter of the last completed session in the arc since its last count reset, for the A, B, C rotation.
    public func lastLetter(arcId: UUID) async throws -> String? {
        try await database.writer.read { db in
            let resetAt = try String.fetchOne(
                db, sql: "SELECT count_reset_at FROM arc WHERE id = ?", arguments: [arcId.sql])
            var request = Session.filter(Column("arc_id") == arcId.sql)
                .filter(Column("status") == SessionStatus.completed.rawValue)
                .filter(Columns.deletedAt == nil)
            if let resetAt { request = request.filter(Column("started_at") >= resetAt) }
            return try request.order(Column("started_at").desc).fetchOne(db)?.planSnapshot.letter
        }
    }

    public func inProgress(athleteId: UUID) async throws -> Session? {
        try await database.writer.read { db in
            try Session.filter(
                Columns.athleteId == athleteId.sql && Column("status") == SessionStatus.inProgress.rawValue
                    && Columns.deletedAt == nil
            ).fetchOne(db)
        }
    }

    public func session(id: UUID) async throws -> Session? {
        try await database.writer.read { db in
            try Session.filter(key: id).filter(Columns.deletedAt == nil).fetchOne(db)
        }
    }

    /// Live sessions, newest first.
    public func sessions(athleteId: UUID) async throws -> [Session] {
        try await database.writer.read { db in
            try Session.filter(Columns.athleteId == athleteId.sql && Columns.deletedAt == nil)
                .order(Column("started_at").desc)
                .fetchAll(db)
        }
    }

    /// Inserts or updates a set. Written on every change so a killed app loses nothing.
    public func save(_ set: LoggedSet) async throws {
        try await database.writer.write { db in try set.save(db) }
    }

    public func save(_ round: LoggedRound) async throws {
        try await database.writer.write { db in try round.save(db) }
    }

    /// Live sets of a session, in exercise order then set number.
    public func sets(sessionId: UUID) async throws -> [LoggedSet] {
        try await database.writer.read { db in
            try LoggedSet.filter(Column("session_id") == sessionId.sql && Columns.deletedAt == nil)
                .order(Column("created_at"), Column("set_number"))
                .fetchAll(db)
        }
    }

    /// The fight round record of a block, created empty on first use.
    public func round(for session: Session, block: PlanSnapshot.Block, now: Date = .now) async throws -> LoggedRound {
        try await database.writer.write { db in
            if let existing = try LoggedRound.filter(Column("session_id") == session.id.sql)
                .filter(Column("block_id") == block.blockId.sql).filter(Columns.deletedAt == nil).fetchOne(db)
            {
                return existing
            }
            let round = LoggedRound(
                id: UUIDv7.make(at: now), athleteId: session.athleteId, sessionId: session.id, blockId: block.blockId,
                createdAt: now)
            try round.insert(db)
            return round
        }
    }

    public func rounds(sessionId: UUID) async throws -> [LoggedRound] {
        try await database.writer.read { db in
            try LoggedRound.filter(Column("session_id") == sessionId.sql && Columns.deletedAt == nil).fetchAll(db)
        }
    }

    /// Removes a set added by mistake during the session (soft delete).
    public func deleteSet(id: UUID, now: Date = .now) async throws {
        try await database.writer.write { db in
            try Self.softDelete(LoggedSet.self, filter: Columns.id == id.sql, now: now, db)
        }
    }

    public func finish(sessionId: UUID, now: Date = .now) async throws -> Session {
        try await database.writer.write { db in
            guard var session = try Session.filter(key: sessionId).fetchOne(db) else {
                throw PersistenceError.notFound("session", sessionId)
            }
            session.status = .completed
            session.finishedAt = now.roundedToMilliseconds
            session.updatedAt = now.roundedToMilliseconds
            try session.update(db)
            return session
        }
    }

    /// Deletes a session from the journal with its sets and rounds (soft delete). Derived values (XP, records,
    /// streak, numbering) recompute from what is left.
    public func delete(sessionId: UUID, now: Date = .now) async throws {
        try await database.writer.write { db in
            let child = Column("session_id") == sessionId.sql
            try Self.softDelete(LoggedSet.self, filter: child, now: now, db)
            try Self.softDelete(LoggedRound.self, filter: child, now: now, db)
            try Self.softDelete(Session.self, filter: Columns.id == sessionId.sql, now: now, db)
        }
    }

    public func number(of session: Session) async throws -> Number {
        try await database.writer.read { db in
            let started = ISO8601Millis.format(session.startedAt)
            let global =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COUNT(*) FROM session
                        WHERE athlete_id = ? AND deleted_at IS NULL AND started_at <= ?
                        """, arguments: [session.athleteId.sql, started]) ?? 0
            let resetAt = try String.fetchOne(
                db, sql: "SELECT count_reset_at FROM arc WHERE id = ?", arguments: [session.arcId.sql])
            let inArc =
                try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COUNT(*) FROM session
                        WHERE arc_id = ? AND deleted_at IS NULL AND started_at <= ?
                        AND (? IS NULL OR started_at >= ?)
                        """, arguments: [session.arcId.sql, started, resetAt, resetAt]) ?? 0
            return Number(global: global, inArc: inArc)
        }
    }

    private static func softDelete<R: HTSRecord>(
        _: R.Type, filter: SQLExpression, now: Date, _ db: Database
    ) throws {
        let stamp = ISO8601Millis.format(now)
        try R.filter(filter && Columns.deletedAt == nil)
            .updateAll(db, [Column("deleted_at").set(to: stamp), Column("updated_at").set(to: stamp)])
    }
}
