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
    /// The current arc, a free arc or an open monthly arc (#210).
    private(set) var canTrain = false

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
        if let arcId = found?.arc.id {
            canTrain = (try? await ArcService(database).canTrain(arcId: arcId)) ?? false
        } else {
            canTrain = false
        }
    }

    /// The current arc, the free arcs (Manutenção, Mobilidade) and the open months can be trained; the others are
    /// only shown.
    func start(hasActiveSession: Bool) -> Start {
        guard arc != nil, let plan, canTrain else { return .locked }
        if plan.blocks.isEmpty { return .empty }
        return hasActiveSession ? .busy : .available
    }
}
