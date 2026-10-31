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

        /// Titles unlocked by this session.
        public let newTitles: [TitleID]
        /// Level of each attribute before and after this session (#89).
        public let attributesBefore: [Attribute: AttributeLevel]
        public let attributesAfter: [Attribute: AttributeLevel]

        /// Attributes this session fed, in the FOR, EXP, GÁS, COR, MOB order.
        public var attributeGains: [Attribute] {
            Attribute.allCases.filter { (attributesAfter[$0]?.xp ?? 0) > (attributesBefore[$0]?.xp ?? 0) }
        }

        public var leveledUp: Bool { after.level > before.level }
        public var rankedUp: Bool { after.rank.id != before.rank.id }
    }

    /// An imported activity with what it gives and the HTS workout it falls inside, if any (spec 2026-10-31).
    public struct ActivityEntry: Hashable, Sendable, Identifiable {
        public let activity: ImportedActivity
        public let xp: ActivityXP
        /// The completed workout it overlaps for more than half of its duration; then it gives no XP of its own.
        public let linkedSessionId: UUID?
        public var id: UUID { activity.id }
    }

    private let database: AppDatabase
    private let progression: Progression

    public init(_ database: AppDatabase, progression: Progression = Progression()) {
        self.database = database
        self.progression = progression
    }

    /// Completed live sessions in chronological order, with their sets as progress sees them. The total also counts
    /// the imported activities that are not linked to a workout.
    public func history(athleteId: UUID) async throws -> (sessions: [Session], history: ProgressHistory) {
        try await database.writer.read { db in
            let sessions = try Self.completedSessions(athleteId: athleteId, db)
            let activities = try entries(athleteId: athleteId, sessions: sessions, db)
            return (
                sessions,
                progression.history(
                    try sessions.map { try Self.historySession($0, db) },
                    activities: activities.map(Self.historyActivity))
            )
        }
    }

    /// Imported activities, oldest first, with their XP and link.
    public func activities(athleteId: UUID) async throws -> [ActivityEntry] {
        try await database.writer.read { db in
            try entries(athleteId: athleteId, sessions: Self.completedSessions(athleteId: athleteId, db), db)
        }
    }

    private func entries(athleteId: UUID, sessions: [Session], _ db: Database) throws -> [ActivityEntry] {
        let windows = sessions.compactMap { session in
            session.finishedAt.map { (id: session.id, startedAt: session.startedAt, finishedAt: $0) }
        }
        return try ActivityRepository.activities(athleteId: athleteId, db).map { activity in
            let linked = progression.isActivityLinked(
                startedAt: activity.startedAt, durationSeconds: activity.durationSeconds,
                sessions: windows.map { (startedAt: $0.startedAt, finishedAt: $0.finishedAt) })
            // Shown inside the workout it overlaps the most.
            let session = windows.max {
                Self.overlap(activity, $0.startedAt, $0.finishedAt)
                    < Self.overlap(activity, $1.startedAt, $1.finishedAt)
            }
            return ActivityEntry(
                activity: activity,
                xp: progression.activityXP(
                    activityType: activity.activityType, durationSeconds: activity.durationSeconds),
                linkedSessionId: linked ? session?.id : nil)
        }
    }

    private static func overlap(_ activity: ImportedActivity, _ start: Date, _ end: Date) -> TimeInterval {
        max(0, min(activity.finishedAt, end).timeIntervalSince(max(activity.startedAt, start)))
    }

    private static func historyActivity(_ entry: ActivityEntry) -> HistoryActivity {
        HistoryActivity(
            activityType: entry.activity.activityType, durationSeconds: entry.activity.durationSeconds,
            linked: entry.linkedSessionId != nil)
    }

    private static func attributeXP(_ entries: [ActivityEntry]) -> [ActivityAttributeXP] {
        entries.filter { $0.linkedSessionId == nil }
            .map { ActivityAttributeXP(attributes: $0.xp.attributes, attributeXP: $0.xp.attributeXP) }
    }

    public func completion(sessionId: UUID) async throws -> Completion? {
        try await database.writer.read { db in
            guard let session = try Session.filter(key: sessionId).fetchOne(db) else { return nil }
            let sessions = try Self.completedSessions(athleteId: session.athleteId, db)
            guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return nil }
            let sets = try sessions.map { try Self.historySession($0, db) }
            // Activities that started before this workout count in both pictures.
            let earlier = try entries(athleteId: session.athleteId, sessions: sessions, db)
                .filter { $0.activity.startedAt < session.startedAt }
            let after = progression.history(Array(sets[...index]), activities: earlier.map(Self.historyActivity))
            let before = progression.history(Array(sets[..<index]), activities: earlier.map(Self.historyActivity))
            let progress = after.sessions[index]
            let names = Dictionary(
                session.planSnapshot.blocks.flatMap(\.exercises).map { ($0.exerciseId.sql, $0.name) },
                uniquingKeysWith: { first, _ in first })
            let facts = try Self.titleSessions(sessions, history: after, db)
            let titlesBefore = Set(progression.titles(Array(facts[..<index])).map(\.id))
            let newTitles = progression.titles(Array(facts[...index])).map(\.id).filter { !titlesBefore.contains($0) }
            let attributeSets = try sessions[...index].map { try Self.attributeSets($0, db) }
            return Completion(
                session: session, progress: progress, before: before, after: after,
                recordNames: progress.records.compactMap { names[$0] }, newTitles: newTitles,
                attributesBefore: progression.attributeLevels(
                    attributeSets.dropLast().flatMap { $0 }, activities: Self.attributeXP(earlier)),
                attributesAfter: progression.attributeLevels(
                    attributeSets.flatMap { $0 }, activities: Self.attributeXP(earlier)))
        }
    }

    /// Level of each attribute from the sets of completed sessions; attributes come from the session snapshot.
    public func attributeLevels(athleteId: UUID) async throws -> [Attribute: AttributeLevel] {
        try await database.writer.read { db in
            let sessions = try Self.completedSessions(athleteId: athleteId, db)
            let sets = try sessions.flatMap { try Self.attributeSets($0, db) }
            let activities = try entries(athleteId: athleteId, sessions: sessions, db)
            return progression.attributeLevels(sets, activities: Self.attributeXP(activities))
        }
    }

    /// The sets of one session as the attributes see them; attributes come from the session snapshot.
    private static func attributeSets(_ session: Session, _ db: Database) throws -> [AttributeSet] {
        var attributes: [UUID: [Attribute]] = [:]
        for block in session.planSnapshot.blocks {
            for exercise in block.exercises { attributes[exercise.prescribedExerciseId] = block.attributes }
        }
        var sets = try LoggedSet.filter(Column("session_id") == session.id.sql)
            .filter(Columns.deletedAt == nil).fetchAll(db)
            .map { AttributeSet(attributes: attributes[$0.prescribedExerciseId] ?? [], completed: $0.completed) }
        // Each complete fight round counts as a completed set of its block (docs/decisions/0027).
        let blockAttributes = Dictionary(
            session.planSnapshot.blocks.map { ($0.blockId, $0.attributes) }, uniquingKeysWith: { a, _ in a })
        for round in try LoggedRound.filter(Column("session_id") == session.id.sql)
            .filter(Columns.deletedAt == nil).fetchAll(db)
        {
            sets += Array(
                repeating: AttributeSet(attributes: blockAttributes[round.blockId] ?? [], completed: true),
                count: max(round.roundsCompleted, 0))
        }
        return sets
    }

    /// Unlocked titles with their date, in unlock order.
    public func titles(athleteId: UUID) async throws -> [UnlockedTitle] {
        try await database.writer.read { db in
            let sessions = try Self.completedSessions(athleteId: athleteId, db)
            let history = progression.history(try sessions.map { try Self.historySession($0, db) })
            return progression.titles(try Self.titleSessions(sessions, history: history, db))
        }
    }

    /// What each completed session contributes to the titles (docs/decisions/0021).
    private static func titleSessions(
        _ sessions: [Session], history: ProgressHistory, _ db: Database
    ) throws -> [TitleSession] {
        // The session that closed each completed arc is the last completed one in it.
        guard let athleteId = sessions.first?.athleteId else { return [] }
        let completedArcs = try Arc.filter(Columns.athleteId == athleteId.sql)
            .filter(Column("status") == ArcStatus.completed.rawValue)
            .filter(Columns.deletedAt == nil).fetchAll(db)
        var closing: [UUID: Arc] = [:]
        for arc in completedArcs {
            if let last = sessions.last(where: { $0.arcId == arc.id }) { closing[last.id] = arc }
        }
        let firstClosing = sessions.first { closing[$0.id] != nil }?.id
        var arcs: [UUID: Arc] = [:]
        for id in Set(sessions.map(\.arcId)) { arcs[id] = try Arc.filter(key: id).fetchOne(db) }
        var goals: [UUID: Int] = [:]
        for id in arcs.keys {
            goals[id] = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM workout_template WHERE arc_id = ? AND deleted_at IS NULL",
                arguments: [id.sql])
        }
        return try sessions.enumerated().map { index, session in
            let names = Dictionary(
                session.planSnapshot.blocks.flatMap(\.exercises).map { ($0.exerciseId, $0.name) },
                uniquingKeysWith: { first, _ in first })
            let pullUps = try LoggedSet.filter(Column("session_id") == session.id.sql)
                .filter(Column("completed") == true).filter(Columns.deletedAt == nil).fetchAll(db)
                .filter { names[$0.exerciseId].map { PullUp.names.contains(ExerciseName.normalize($0)) } ?? false }
                .count
            let filler = arcs[session.arcId]?.kind == .filler
            var completedArc: TitleSession.CompletedArc?
            if let arc = closing[session.id] {
                completedArc = session.id == firstClosing ? .first : (arc.kind == .special ? .special : nil)
            }
            return TitleSession(
                localDate: session.localDate, weeklyGoal: filler ? nil : goals[session.arcId],
                records: history.sessions[index].records.count, pullUpSets: pullUps, completedArc: completedArc)
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

    /// Sets and fight rounds of a session as progress sees them (docs/decisions/0027).
    private static func historySession(_ session: Session, _ db: Database) throws -> HistorySession {
        let rounds = try LoggedRound.filter(Column("session_id") == session.id.sql).filter(Columns.deletedAt == nil)
            .fetchAll(db)
            .map { HistoryRound(roundsCompleted: $0.roundsCompleted, weightsKg: $0.weights.map(\.weightKg)) }
        return HistorySession(sets: try historySets(session, db), rounds: rounds)
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
