import Foundation
import HTSDomain
import HTSPersistence
import Observation

/// Everything the Status tab shows, derived from the records on every load.
@MainActor
@Observable
final class StatusModel {
    struct NextWorkout {
        let arc: Arc
        let plan: TemplatePlan
        let completed: Int
        let total: Int?
    }

    private(set) var history: ProgressHistory?
    private(set) var next: NextWorkout?
    private(set) var streak: Streak?
    private(set) var battle: Battle?
    var weekDone: Int { streak?.thisWeek.done ?? 0 }
    private(set) var weekGoal = 0

    private let database: AppDatabase
    private let athleteId: UUID

    init(database: AppDatabase, athleteId: UUID) {
        self.database = database
        self.athleteId = athleteId
    }

    var levelProgress: Progression.LevelProgress? {
        history.map { Progression().levelProgress(xp: $0.totalXp) }
    }

    func load(today: LocalDate = .today) async {
        history = try? await ProgressService(database).history(athleteId: athleteId).history
        streak = try? await ProgressService(database).streak(athleteId: athleteId, today: today)
        battle = try? await BattleRepository(database).current(athleteId: athleteId, today: today)
        let plans = PlanRepository(database)
        guard let arc = try? await plans.currentArc(athleteId: athleteId),
            let plan = try? await plans.plan(arcId: arc.id)
        else {
            next = nil
            weekGoal = streak?.thisWeek.goal ?? 0
            return
        }
        let schedule = ArcSchedule(plan)
        weekGoal = schedule.weeklyGoal
        let last = try? await SessionRepository(database).lastLetter(arcId: arc.id)
        let completed =
            (try? await ArcService(database).summaries(athleteId: athleteId, sagaId: arc.sagaId))?
            .first { $0.arc.id == arc.id }?.completedSessions ?? 0
        if let letter = schedule.next(after: last),
            let template = plan.templates.first(where: { $0.template.letter == letter })
        {
            next = NextWorkout(arc: arc, plan: template, completed: completed, total: schedule.totalSessions)
        } else {
            next = nil
        }
    }
}
