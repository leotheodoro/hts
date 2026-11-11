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
    /// The current arc, a free arc, an open monthly arc (#210) or a treino teste (#216).
    private(set) var canTrain = false
    /// EVOLUÇÃO of a treino teste: the last run beside the one before (#216).
    private(set) var evolution: TestEvolution?

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
        let open = (try? await ArcService(database).canTrain(templateId: templateId)) ?? false
        canTrain = found != nil && open
        if found?.plan.template.isTest == true,
            let runs = try? await SessionRepository(database).testRuns(templateId: templateId)
        {
            evolution = TestEvolution(runs: runs)
        } else {
            evolution = nil
        }
    }

    /// The current arc, the free arcs (Manutenção, Mobilidade), the open months and the tests can be trained; the
    /// others are only shown.
    func start(hasActiveSession: Bool) -> Start {
        guard arc != nil, let plan, canTrain else { return .locked }
        if plan.blocks.isEmpty { return .empty }
        return hasActiveSession ? .busy : .available
    }
}
