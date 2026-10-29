import Foundation
import HTSDomain
import HTSPersistence
import Observation

/// The workout page: one template, read only. Workouts start only from here (#86).
@MainActor
@Observable
final class WorkoutModel {
    enum Start: Equatable {
        /// "Iniciar treino".
        case available
        /// Another workout is in progress.
        case busy
        /// Arc not current yet (or already completed).
        case locked
        case empty
    }

    private(set) var arc: Arc?
    private(set) var plan: TemplatePlan?

    private let database: AppDatabase
    private let templateId: UUID

    init(database: AppDatabase, templateId: UUID) {
        self.database = database
        self.templateId = templateId
    }

    func load() async {
        let found = try? await PlanRepository(database).template(id: templateId)
        arc = found?.arc
        plan = found?.plan
    }

    /// The current arc and the free arcs (Manutenção, Mobilidade) can be trained; the others are only shown.
    func start(hasActiveSession: Bool) -> Start {
        guard let arc, let plan else { return .locked }
        guard arc.status == .current || arc.kind == .filler else { return .locked }
        if plan.blocks.isEmpty { return .empty }
        return hasActiveSession ? .busy : .available
    }
}
