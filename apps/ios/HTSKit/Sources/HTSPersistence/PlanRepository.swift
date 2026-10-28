import Foundation
import GRDB
import HTSDomain

/// Reads and writes the plan side: sagas, arcs, workout templates, blocks and prescriptions.
public struct PlanRepository: Sendable {
    private let database: AppDatabase

    public init(_ database: AppDatabase) {
        self.database = database
    }

    /// Inserts or updates any plan record. Callers set `updatedAt`.
    public func save(_ record: some HTSRecord) async throws {
        try await database.writer.write { db in try record.save(db) }
    }

    public func saveAll(_ records: [any HTSRecord]) async throws {
        try await database.writer.write { db in
            for record in records { try record.save(db) }
        }
    }

    public func arcs(athleteId: UUID, sagaId: UUID) async throws -> [Arc] {
        try await database.writer.read { db in
            try Arc.filter(
                Columns.athleteId == athleteId.sql && Column("saga_id") == sagaId.sql && Columns.deletedAt == nil
            )
            .order(Columns.position)
            .fetchAll(db)
        }
    }

    public func currentArc(athleteId: UUID) async throws -> Arc? {
        try await database.writer.read { db in
            try Arc.filter(
                Columns.athleteId == athleteId.sql && Column("status") == ArcStatus.current.rawValue
                    && Columns.deletedAt == nil
            ).fetchOne(db)
        }
    }

    /// The arc with all its live templates, blocks and prescriptions, in position order.
    public func plan(arcId: UUID) async throws -> ArcPlan? {
        try await database.writer.read { db in
            guard let arc = try Arc.filter(key: arcId).filter(Columns.deletedAt == nil).fetchOne(db) else {
                return nil
            }
            let templates = try live(WorkoutTemplate.self).filter(Column("arc_id") == arcId.sql).fetchAll(db)
            return ArcPlan(arc: arc, templates: try templates.map { try Self.templatePlan($0, db) })
        }
    }

    /// Copies a template, with its blocks and prescriptions, into another arc (docs/decisions/0015). The copy points
    /// back with `sourceTemplateId`; later edits to either side do not affect the other.
    @discardableResult
    public func copyTemplate(id: UUID, toArc arcId: UUID, letter: String, position: Int, now: Date = .now)
        async throws -> WorkoutTemplate
    {
        try await database.writer.write { db in
            try Self.copyTemplate(id: id, toArc: arcId, letter: letter, position: position, now: now, db)
        }
    }

    static func copyTemplate(
        id: UUID, toArc arcId: UUID, letter: String, position: Int, now: Date, _ db: Database
    ) throws -> WorkoutTemplate {
        guard let source = try WorkoutTemplate.filter(key: id).fetchOne(db) else {
            throw PersistenceError.notFound("workout_template", id)
        }
        let plan = try templatePlan(source, db)
        let stamp = now.roundedToMilliseconds
        var copy = source
        copy.id = UUIDv7.make(at: now)
        copy.arcId = arcId
        copy.sourceTemplateId = source.id
        copy.letter = letter
        copy.position = position
        copy.createdAt = stamp
        copy.updatedAt = stamp
        try copy.insert(db)
        for blockPlan in plan.blocks {
            var block = blockPlan.block
            block.id = UUIDv7.make(at: now)
            block.workoutTemplateId = copy.id
            block.createdAt = stamp
            block.updatedAt = stamp
            try block.insert(db)
            for planned in blockPlan.exercises {
                var prescription = planned.prescription
                prescription.id = UUIDv7.make(at: now)
                prescription.blockId = block.id
                prescription.createdAt = stamp
                prescription.updatedAt = stamp
                try prescription.insert(db)
            }
        }
        return copy
    }

    private static func templatePlan(_ template: WorkoutTemplate, _ db: Database) throws -> TemplatePlan {
        let blocks = try live(Block.self).filter(Column("workout_template_id") == template.id.sql).fetchAll(db)
        return TemplatePlan(
            template: template,
            blocks: try blocks.map { block in
                let prescriptions = try live(PrescribedExercise.self).filter(Column("block_id") == block.id.sql)
                    .fetchAll(db)
                let exerciseIds = prescriptions.map(\.exerciseId)
                let exercises = try Exercise.filter(exerciseIds.map(\.sql).contains(Columns.id)).fetchAll(db)
                let byId = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
                return BlockPlan(
                    block: block,
                    exercises: try prescriptions.map { prescription in
                        guard let exercise = byId[prescription.exerciseId] else {
                            throw PersistenceError.notFound("exercise", prescription.exerciseId)
                        }
                        return PlannedExercise(prescription: prescription, exercise: exercise)
                    })
            })
    }
}

/// Not-deleted rows in position order.
private func live<R: HTSRecord>(_: R.Type) -> QueryInterfaceRequest<R> {
    R.filter(Columns.deletedAt == nil).order(Columns.position)
}

public enum PersistenceError: Error, Equatable {
    case notFound(String, UUID)
}
