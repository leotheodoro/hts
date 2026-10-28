import Foundation
import HTSDomain
import HTSPersistence
import Observation

/// State of the Arcos tab: the saga of the current year and its arcs.
@MainActor
@Observable
final class ArcsModel {
    private(set) var saga: Saga?
    private(set) var summaries: [ArcService.Summary] = []
    private(set) var error: String?
    /// The competition ahead, to spotlight the special arc in its week.
    private(set) var battle: Battle?

    private let database: AppDatabase
    private let athleteId: UUID

    init(database: AppDatabase, athleteId: UUID) {
        self.database = database
        self.athleteId = athleteId
    }

    var service: ArcService { ArcService(database) }

    func load(now: Date = .now) async {
        do {
            let year = LocalDate(now, in: .current).year
            let saga = try await service.saga(athleteId: athleteId, year: year, now: now)
            self.saga = saga
            summaries = try await service.summaries(athleteId: athleteId, sagaId: saga.id)
            battle = try await BattleRepository(database).current(
                athleteId: athleteId, today: LocalDate(now, in: .current))
            error = nil
        } catch {
            self.error = String(describing: error)
        }
    }

    func newDraft() -> ArcDraft {
        ArcDraft(startDate: .today)
    }

    func draft(for arcId: UUID) async -> ArcDraft? {
        guard let plan = try? await PlanRepository(database).plan(arcId: arcId) else { return nil }
        return ArcDraft(plan, today: .today)
    }

    func reusableTemplates(excluding arcId: UUID?) async -> [(arc: Arc, template: WorkoutTemplate)] {
        (try? await service.reusableTemplates(athleteId: athleteId, excludingArc: arcId)) ?? []
    }

    /// Returns false and keeps the error when saving fails.
    func save(_ draft: ArcDraft) async -> Bool {
        guard let saga else { return false }
        do {
            try await service.save(draft, athleteId: athleteId, sagaId: saga.id)
            await load()
            return true
        } catch {
            self.error = String(describing: error)
            return false
        }
    }

    func restartCount(arcId: UUID) async {
        do {
            try await service.restartCount(arcId: arcId)
            await load()
        } catch {
            self.error = String(describing: error)
        }
    }
}
