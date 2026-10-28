/// An arc with its whole plan, in display order.
public struct ArcPlan: Hashable, Sendable {
    public var arc: Arc
    public var templates: [TemplatePlan]

    public init(arc: Arc, templates: [TemplatePlan]) {
        self.arc = arc
        self.templates = templates
    }
}

public struct TemplatePlan: Hashable, Sendable {
    public var template: WorkoutTemplate
    public var blocks: [BlockPlan]

    public init(template: WorkoutTemplate, blocks: [BlockPlan]) {
        self.template = template
        self.blocks = blocks
    }
}

public struct BlockPlan: Hashable, Sendable {
    public var block: Block
    public var exercises: [PlannedExercise]

    public init(block: Block, exercises: [PlannedExercise]) {
        self.block = block
        self.exercises = exercises
    }
}

public struct PlannedExercise: Hashable, Sendable {
    public var prescription: PrescribedExercise
    public var exercise: Exercise

    public init(prescription: PrescribedExercise, exercise: Exercise) {
        self.prescription = prescription
        self.exercise = exercise
    }
}
