import Foundation
import GRDB
import HTSDomain

/// Saves the workout template editor: template fields, blocks and prescriptions in order.
public struct TemplateService: Sendable {
    private let database: AppDatabase

    public init(_ database: AppDatabase) {
        self.database = database
    }

    public func draft(templateId: UUID) async throws -> TemplateDraft? {
        try await database.writer.read { db in
            guard let template = try WorkoutTemplate.filter(key: templateId).fetchOne(db) else { return nil }
            return TemplateDraft(try PlanRepository.templatePlan(template, db))
        }
    }

    /// Updates rows that still exist, inserts new ones and soft-deletes the ones removed from the editor.
    /// Exercises are found or created in the catalog by normalized name (docs/decisions/0016).
    public func save(_ draft: TemplateDraft, now: Date = .now) async throws {
        precondition(draft.isValid, "save only valid drafts")
        try await database.writer.write { db in
            let stamp = now.roundedToMilliseconds
            guard var template = try WorkoutTemplate.filter(key: draft.templateId).fetchOne(db) else {
                throw PersistenceError.notFound("workout_template", draft.templateId)
            }
            template.name = draft.name.trimmingCharacters(in: .whitespaces)
            template.focus = draft.focus.trimmingCharacters(in: .whitespaces).isEmpty ? nil : draft.focus
            template.updatedAt = stamp
            try template.update(db)

            let keptBlocks = Set(draft.blocks.compactMap(\.existingId))
            let keptPrescriptions = Set(draft.blocks.flatMap(\.exercises).compactMap(\.existingId))
            let oldBlocks = try Block.filter(
                Column("workout_template_id") == template.id.sql && Columns.deletedAt == nil
            ).fetchAll(db)
            for var block in oldBlocks {
                let prescriptions = try PrescribedExercise.filter(
                    Column("block_id") == block.id.sql && Columns.deletedAt == nil
                ).fetchAll(db)
                for var prescription in prescriptions where !keptPrescriptions.contains(prescription.id) {
                    prescription.deletedAt = stamp
                    prescription.updatedAt = stamp
                    try prescription.update(db)
                }
                if !keptBlocks.contains(block.id) {
                    block.deletedAt = stamp
                    block.updatedAt = stamp
                    try block.update(db)
                }
            }

            for (blockIndex, item) in draft.blocks.enumerated() {
                var block =
                    try item.existingId.flatMap { try Block.filter(key: $0).fetchOne(db) }
                    ?? Block(
                        id: UUIDv7.make(at: now), athleteId: template.athleteId, workoutTemplateId: template.id,
                        kind: item.kind, attributes: item.attributes, position: blockIndex, createdAt: now)
                block.kind = item.kind
                block.attributes = item.attributes
                block.durationMinutes = item.kind == .fightRound ? item.durationMinutes : nil
                block.position = blockIndex
                block.updatedAt = stamp
                try block.save(db)

                for (exerciseIndex, entry) in item.exercises.enumerated() {
                    guard let sets = entry.sets, let parsed = entry.parsed else { continue }
                    var exercise = try ExerciseCatalog.findOrCreate(
                        name: entry.name, athleteId: template.athleteId, defaultAttribute: item.attributes.first,
                        unit: entry.unit, perSide: parsed.perSide, now: now, db)
                    if exercise.unit != entry.unit || (parsed.perSide && !exercise.perSide) {
                        exercise.unit = entry.unit
                        exercise.perSide = exercise.perSide || parsed.perSide
                        exercise.updatedAt = stamp
                        try exercise.update(db)
                    }
                    var prescription =
                        try entry.existingId.flatMap { try PrescribedExercise.filter(key: $0).fetchOne(db) }
                        ?? PrescribedExercise(
                            id: UUIDv7.make(at: now), athleteId: template.athleteId, blockId: block.id,
                            exerciseId: exercise.id, setsMin: sets.min, targets: parsed.targets,
                            position: exerciseIndex, createdAt: now)
                    prescription.blockId = block.id
                    prescription.exerciseId = exercise.id
                    prescription.setsMin = sets.min
                    prescription.setsMax = sets.max
                    prescription.targets = parsed.targets
                    prescription.restSeconds = entry.restSeconds
                    prescription.position = exerciseIndex
                    prescription.updatedAt = stamp
                    try prescription.save(db)
                }
            }
        }
    }
}
