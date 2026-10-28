import Foundation

/// The workout template as it was when a session started, so editing the plan later never changes history
/// (docs/decisions/0017). Same JSON as `PlanSnapshotSchema` in apps/api/src/db/snapshot.ts.
public struct PlanSnapshot: Hashable, Sendable, Codable {
    public struct Block: Hashable, Sendable, Codable {
        public var blockId: UUID
        public var kind: BlockKind
        public var attributes: [Attribute]
        public var durationMinutes: Int?
        public var exercises: [Exercise]
    }

    public struct Exercise: Hashable, Sendable, Codable {
        public var prescribedExerciseId: UUID
        public var exerciseId: UUID
        public var name: String
        public var unit: ExerciseUnit
        public var perSide: Bool
        public var setsMin: Int
        public var setsMax: Int
        public var targets: [SetTarget]
        public var restSeconds: Int?
    }

    public var workoutTemplateId: UUID
    public var letter: String
    public var name: String
    public var focus: String?
    public var blocks: [Block]

    public init(_ plan: TemplatePlan) {
        workoutTemplateId = plan.template.id
        letter = plan.template.letter
        name = plan.template.name
        focus = plan.template.focus
        blocks = plan.blocks.map { blockPlan in
            Block(
                blockId: blockPlan.block.id, kind: blockPlan.block.kind, attributes: blockPlan.block.attributes,
                durationMinutes: blockPlan.block.durationMinutes,
                exercises: blockPlan.exercises.map { planned in
                    Exercise(
                        prescribedExerciseId: planned.prescription.id, exerciseId: planned.exercise.id,
                        name: planned.exercise.name, unit: planned.exercise.unit, perSide: planned.exercise.perSide,
                        setsMin: planned.prescription.setsMin, setsMax: planned.prescription.setsMax,
                        targets: planned.prescription.targets, restSeconds: planned.prescription.restSeconds)
                })
        }
    }
}

// Ids are written in lowercase, like every id in the database; JSONEncoder would write uppercase. Optionals are
// written as null so the shape matches the Zod schema.
extension PlanSnapshot {
    private enum CodingKeys: String, CodingKey { case workoutTemplateId, letter, name, focus, blocks }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(workoutTemplateId.uuidString.lowercased(), forKey: .workoutTemplateId)
        try c.encode(letter, forKey: .letter)
        try c.encode(name, forKey: .name)
        try c.encode(focus, forKey: .focus)
        try c.encode(blocks, forKey: .blocks)
    }
}

extension PlanSnapshot.Block {
    private enum CodingKeys: String, CodingKey { case blockId, kind, attributes, durationMinutes, exercises }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(blockId.uuidString.lowercased(), forKey: .blockId)
        try c.encode(kind, forKey: .kind)
        try c.encode(attributes, forKey: .attributes)
        try c.encode(durationMinutes, forKey: .durationMinutes)
        try c.encode(exercises, forKey: .exercises)
    }
}

extension PlanSnapshot.Exercise {
    private enum CodingKeys: String, CodingKey {
        case prescribedExerciseId, exerciseId, name, unit, perSide, setsMin, setsMax, targets, restSeconds
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(prescribedExerciseId.uuidString.lowercased(), forKey: .prescribedExerciseId)
        try c.encode(exerciseId.uuidString.lowercased(), forKey: .exerciseId)
        try c.encode(name, forKey: .name)
        try c.encode(unit, forKey: .unit)
        try c.encode(perSide, forKey: .perSide)
        try c.encode(setsMin, forKey: .setsMin)
        try c.encode(setsMax, forKey: .setsMax)
        try c.encode(targets, forKey: .targets)
        try c.encode(restSeconds, forKey: .restSeconds)
    }
}
