import Foundation

/// What the workout template editor edits: blocks and exercises in order, targets as typed.
public struct TemplateDraft: Hashable, Sendable {
    public struct BlockDraft: Hashable, Sendable, Identifiable {
        public let id: UUID
        /// Nil for blocks added in this edit.
        public var existingId: UUID?
        public var kind: BlockKind
        public var attributes: [Attribute]
        public var durationMinutes: Int
        public var exercises: [ExerciseDraft]

        public init(
            id: UUID = UUID(), existingId: UUID? = nil, kind: BlockKind = .strength,
            attributes: [Attribute] = [.strength], durationMinutes: Int = 8, exercises: [ExerciseDraft] = []
        ) {
            self.id = id
            self.existingId = existingId
            self.kind = kind
            self.attributes = attributes
            self.durationMinutes = durationMinutes
            self.exercises = exercises
        }

        public var isValid: Bool {
            !attributes.isEmpty && !exercises.isEmpty && exercises.allSatisfy(\.isValid)
                && (kind != .fightRound || (1...60).contains(durationMinutes))
        }
    }

    public struct ExerciseDraft: Hashable, Sendable, Identifiable {
        public let id: UUID
        /// Nil for prescriptions added in this edit.
        public var existingId: UUID?
        public var name: String
        public var unit: ExerciseUnit
        /// "3" or "3 a 4".
        public var setsText: String
        /// "8", "6-6-3-3", "12/12", "10-20 s", "máx".
        public var targetText: String
        public var restSeconds: Int?

        public init(
            id: UUID = UUID(), existingId: UUID? = nil, name: String = "", unit: ExerciseUnit = .reps,
            setsText: String = "3", targetText: String = "", restSeconds: Int? = nil
        ) {
            self.id = id
            self.existingId = existingId
            self.name = name
            self.unit = unit
            self.setsText = setsText
            self.targetText = targetText
            self.restSeconds = restSeconds
        }

        public var sets: TargetNotation.Sets? { TargetNotation.parseSets(setsText) }

        public var parsed: TargetNotation.Parsed? {
            sets.flatMap { TargetNotation.parse(targetText, setsMax: $0.max) }
        }

        public var loadHint: LoadGuide? {
            parsed.flatMap { LoadGuide.hint(for: $0.targets, unit: unit) }
        }

        public var isValid: Bool {
            !name.trimmingCharacters(in: .whitespaces).isEmpty && parsed != nil
                && (restSeconds ?? 1) > 0
        }
    }

    public let templateId: UUID
    public let letter: String
    public var name: String
    public var focus: String
    public var blocks: [BlockDraft]

    public init(_ plan: TemplatePlan) {
        templateId = plan.template.id
        letter = plan.template.letter
        name = plan.template.name
        focus = plan.template.focus ?? ""
        blocks = plan.blocks.map { blockPlan in
            BlockDraft(
                existingId: blockPlan.block.id, kind: blockPlan.block.kind, attributes: blockPlan.block.attributes,
                durationMinutes: blockPlan.block.durationMinutes ?? 8,
                exercises: blockPlan.exercises.map { planned in
                    ExerciseDraft(
                        existingId: planned.prescription.id, name: planned.exercise.name, unit: planned.exercise.unit,
                        setsText: TargetNotation.formatSets(
                            min: planned.prescription.setsMin, max: planned.prescription.setsMax),
                        targetText: TargetNotation.format(
                            planned.prescription.targets, unit: planned.exercise.unit,
                            perSide: planned.exercise.perSide),
                        restSeconds: planned.prescription.restSeconds)
                })
        }
    }

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && blocks.allSatisfy(\.isValid)
    }
}
