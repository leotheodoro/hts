import Foundation
import GRDB
import HTSDomain

/// Creates and edits arcs from the arc form.
public struct ArcService: Sendable {
    /// An arc with what the list shows.
    public struct Summary: Hashable, Sendable, Identifiable {
        public let arc: Arc
        public let schedule: ArcSchedule
        /// Completed sessions since the last count reset.
        public let completedSessions: Int
        public var id: UUID { arc.id }
    }

    private let database: AppDatabase

    public init(_ database: AppDatabase) {
        self.database = database
    }

    /// The saga of `year`, created on first use ("Saga 2026").
    public func saga(athleteId: UUID, year: Int, now: Date = .now) async throws -> Saga {
        try await database.writer.write { db in
            if let saga = try Saga.filter(
                Columns.athleteId == athleteId.sql && Column("year") == year && Columns.deletedAt == nil
            ).fetchOne(db) {
                return saga
            }
            let saga = Saga(
                id: UUIDv7.make(at: now), athleteId: athleteId, year: year, name: "Saga \(year)", createdAt: now)
            try saga.insert(db)
            return saga
        }
    }

    /// Live arcs of the saga in order, with schedule and progress.
    public func summaries(athleteId: UUID, sagaId: UUID) async throws -> [Summary] {
        try await database.writer.read { db in
            let arcs = try Arc.filter(
                Columns.athleteId == athleteId.sql && Column("saga_id") == sagaId.sql && Columns.deletedAt == nil
            ).order(Columns.position).fetchAll(db)
            return try arcs.map { arc in
                let letters = try String.fetchAll(
                    db,
                    sql:
                        "SELECT letter FROM workout_template WHERE arc_id = ? AND deleted_at IS NULL ORDER BY position",
                    arguments: [arc.id.sql])
                let completed = try Self.completedSessions(arc: arc, db)
                return Summary(
                    arc: arc, schedule: ArcSchedule(letters: letters, weeks: arc.weeks, startDate: arc.startDate),
                    completedSessions: completed)
            }
        }
    }

    /// Templates of other arcs that can be reused, with the arc name ("Recrutamento · A · Linha de Frente").
    public func reusableTemplates(athleteId: UUID, excludingArc arcId: UUID?) async throws -> [(
        arc: Arc, template: WorkoutTemplate
    )] {
        try await database.writer.read { db in
            let arcs = try Arc.filter(Columns.athleteId == athleteId.sql && Columns.deletedAt == nil)
                .order(Columns.position).fetchAll(db)
            return try arcs.filter { $0.id != arcId }.flatMap { arc in
                try WorkoutTemplate.filter(Column("arc_id") == arc.id.sql && Columns.deletedAt == nil)
                    .order(Columns.position).fetchAll(db).map { (arc, $0) }
            }
        }
    }

    /// Saves the form. A new arc becomes current when there is none, otherwise it joins the queue.
    @discardableResult
    public func save(_ draft: ArcDraft, athleteId: UUID, sagaId: UUID, now: Date = .now) async throws -> Arc {
        precondition(draft.isValid, "save only valid drafts")
        return try await database.writer.write { db in
            let stamp = now.roundedToMilliseconds
            var arc: Arc
            if let arcId = draft.arcId {
                guard let existing = try Arc.filter(key: arcId).fetchOne(db) else {
                    throw PersistenceError.notFound("arc", arcId)
                }
                arc = existing
            } else {
                let hasCurrent =
                    try Arc.filter(
                        Columns.athleteId == athleteId.sql && Column("status") == ArcStatus.current.rawValue
                            && Columns.deletedAt == nil
                    ).fetchCount(db) > 0
                let position =
                    (try Int.fetchOne(
                        db, sql: "SELECT MAX(position) FROM arc WHERE saga_id = ? AND deleted_at IS NULL",
                        arguments: [sagaId.sql]) ?? -1) + 1
                arc = Arc(
                    id: UUIDv7.make(at: now), athleteId: athleteId, sagaId: sagaId, name: draft.name, weeks: nil,
                    startDate: nil, status: hasCurrent ? .queued : .current, position: position, createdAt: now)
            }
            arc.name = draft.name.trimmingCharacters(in: .whitespaces)
            arc.kanji = Self.nonEmpty(draft.kanji)
            arc.program = Self.nonEmpty(draft.program)
            arc.kind = draft.kind
            arc.weeks = draft.hasDuration ? draft.weeks : nil
            arc.startDate = draft.hasDuration ? draft.startDate : nil
            arc.updatedAt = stamp
            try arc.save(db)

            // Templates removed from the form are soft-deleted; the rest follow the form order.
            let kept = Set(draft.templates.compactMap { if case .existing(let id) = $0.origin { id } else { nil } })
            let current = try WorkoutTemplate.filter(Column("arc_id") == arc.id.sql && Columns.deletedAt == nil)
                .fetchAll(db)
            for var template in current where !kept.contains(template.id) {
                template.deletedAt = stamp
                template.updatedAt = stamp
                try template.update(db)
            }
            for (index, item) in draft.templates.enumerated() {
                let letter = TemplateLetter.letter(at: index)
                switch item.origin {
                case .existing(let id):
                    guard var template = try WorkoutTemplate.filter(key: id).fetchOne(db) else {
                        throw PersistenceError.notFound("workout_template", id)
                    }
                    template.letter = letter
                    template.name = item.name.trimmingCharacters(in: .whitespaces)
                    template.focus = item.focus.flatMap(Self.nonEmpty)
                    template.position = index
                    template.updatedAt = stamp
                    try template.update(db)
                case .new:
                    try WorkoutTemplate(
                        id: UUIDv7.make(at: now), athleteId: athleteId, arcId: arc.id, letter: letter,
                        name: item.name.trimmingCharacters(in: .whitespaces), focus: item.focus.flatMap(Self.nonEmpty),
                        position: index, createdAt: now
                    ).insert(db)
                case .reuse(let sourceId):
                    var copy = try PlanRepository.copyTemplate(
                        id: sourceId, toArc: arc.id, letter: letter, position: index, now: now, db)
                    copy.name = item.name.trimmingCharacters(in: .whitespaces)
                    try copy.update(db)
                }
            }
            return arc
        }
    }

    /// After a finished session: when the arc has all its sessions it becomes completed and the next queued arc of
    /// the saga becomes current. Returns the arc that became current, if any.
    @discardableResult
    public func completeIfDone(arcId: UUID, now: Date = .now) async throws -> Arc? {
        try await database.writer.write { db in
            guard var arc = try Arc.filter(key: arcId).fetchOne(db), arc.status == .current else { return nil }
            let letters = try String.fetchAll(
                db, sql: "SELECT letter FROM workout_template WHERE arc_id = ? AND deleted_at IS NULL",
                arguments: [arc.id.sql])
            let schedule = ArcSchedule(letters: letters, weeks: arc.weeks, startDate: arc.startDate)
            guard schedule.isComplete(completedSessions: try Self.completedSessions(arc: arc, db)) else { return nil }
            let stamp = now.roundedToMilliseconds
            arc.status = .completed
            arc.updatedAt = stamp
            try arc.update(db)
            guard
                var next = try Arc.filter(Column("saga_id") == arc.sagaId.sql)
                    .filter(Column("status") == ArcStatus.queued.rawValue).filter(Columns.deletedAt == nil)
                    .order(Columns.position).fetchOne(db)
            else { return nil }
            next.status = .current
            next.updatedAt = stamp
            try next.update(db)
            return next
        }
    }

    /// "Recomeçar contagem": progress starts over, history stays.
    public func restartCount(arcId: UUID, now: Date = .now) async throws {
        try await database.writer.write { db in
            guard var arc = try Arc.filter(key: arcId).fetchOne(db) else {
                throw PersistenceError.notFound("arc", arcId)
            }
            arc.countResetAt = now.roundedToMilliseconds
            arc.updatedAt = now.roundedToMilliseconds
            try arc.update(db)
        }
    }

    static func completedSessions(arc: Arc, _ db: Database) throws -> Int {
        let reset = arc.countResetAt.map(ISO8601Millis.format)
        return try Int.fetchOne(
            db,
            sql: """
                SELECT COUNT(*) FROM session
                WHERE arc_id = ? AND status = 'completed' AND deleted_at IS NULL AND (? IS NULL OR started_at >= ?)
                """, arguments: [arc.id.sql, reset, reset]) ?? 0
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
