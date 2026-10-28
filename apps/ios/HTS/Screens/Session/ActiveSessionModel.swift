import Foundation
import HTSDomain
import HTSPersistence
import Observation

/// State of the active workout. Every change is written to SQLite right away, so a killed app loses nothing.
@MainActor
@Observable
final class ActiveSessionModel {
    let session: Session
    private(set) var sets: [UUID: [LoggedSet]] = [:]
    private(set) var previous: [UUID: [Int: LoggedSet]] = [:]
    private(set) var number: SessionRepository.Number?
    private(set) var error: String?
    /// The running rest, if any, and the exercise it was started from.
    private(set) var rest: RestTimer?
    private(set) var restExerciseName = ""

    private let repository: SessionRepository
    private let alerts: any RestAlerts
    private let defaultRestSeconds: Int

    init(
        database: AppDatabase, session: Session, defaultRestSeconds: Int = Athlete.defaultRestSeconds,
        alerts: any RestAlerts = LocalNotificationRestAlerts()
    ) {
        self.session = session
        self.defaultRestSeconds = defaultRestSeconds
        self.alerts = alerts
        repository = SessionRepository(database)
        if let stored = RestStore.load(sessionId: session.id), !stored.timer.isFinished(at: .now) {
            rest = stored.timer
            restExerciseName = stored.exerciseName
        }
    }

    /// Starts the rest after a checked set: the exercise's own rest, or the athlete's default.
    func startRest(after exercise: PlanSnapshot.Exercise, now: Date = .now) {
        let seconds = RestTimer.seconds(exerciseRest: exercise.restSeconds, athleteDefault: defaultRestSeconds)
        setRest(RestTimer(startedAt: now, seconds: seconds), exerciseName: exercise.name)
    }

    func adjustRest(by seconds: TimeInterval, now: Date = .now) {
        guard var timer = rest else { return }
        timer.adjust(by: seconds, now: now)
        setRest(timer, exerciseName: restExerciseName)
    }

    func skipRest() {
        setRest(nil, exerciseName: "")
    }

    /// Called by the footer when the countdown reaches zero in the foreground.
    func restDidFinish() {
        rest = nil
        RestStore.save(nil, exerciseName: "", sessionId: session.id)
    }

    private func setRest(_ timer: RestTimer?, exerciseName: String) {
        rest = timer
        restExerciseName = exerciseName
        RestStore.save(timer, exerciseName: exerciseName, sessionId: session.id)
        let alerts = self.alerts
        Task {
            if let timer {
                await alerts.schedule(at: timer.endsAt, exerciseName: exerciseName)
            } else {
                await alerts.cancel()
            }
        }
    }

    var snapshot: PlanSnapshot { session.planSnapshot }

    func load() async {
        do {
            let all = try await repository.sets(sessionId: session.id)
            sets = Dictionary(grouping: all, by: \.prescribedExerciseId)
                .mapValues { $0.sorted { $0.setNumber < $1.setNumber } }
            previous = try await repository.previousSets(for: session)
            number = try await repository.number(of: session)
        } catch {
            self.error = String(describing: error)
        }
    }

    func rows(for exercise: PlanSnapshot.Exercise) -> [LoggedSet] {
        sets[exercise.prescribedExerciseId] ?? []
    }

    func previous(for exercise: PlanSnapshot.Exercise, setNumber: Int) -> LoggedSet? {
        previous[exercise.exerciseId]?[setNumber]
    }

    var uncheckedCount: Int {
        sets.values.joined().filter { !$0.completed }.count
    }

    func update(_ set: LoggedSet) {
        var set = set
        set.updatedAt = Date.now.roundedToMilliseconds
        replace(set)
        Task { await persist(set) }
    }

    func toggle(_ set: LoggedSet, exercise: PlanSnapshot.Exercise) {
        let changed =
            set.completed
            ? SetRules.uncheck(set, at: .now)
            : SetRules.check(
                set, unit: exercise.unit, target: exercise.targets.target(forSet: set.setNumber - 1),
                previous: previous(for: exercise, setNumber: set.setNumber), at: .now)
        replace(changed)
        Task { await persist(changed) }
        if changed.completed { startRest(after: exercise) }
    }

    func addSet(to exercise: PlanSnapshot.Exercise) async {
        do {
            let set = try await repository.addSet(to: session, exercise: exercise)
            sets[exercise.prescribedExerciseId, default: []].append(set)
        } catch {
            self.error = String(describing: error)
        }
    }

    func remove(_ set: LoggedSet) async {
        do {
            try await repository.deleteSet(id: set.id)
            sets[set.prescribedExerciseId]?.removeAll { $0.id == set.id }
        } catch {
            self.error = String(describing: error)
        }
    }

    func finish() async -> Session? {
        skipRest()
        do {
            return try await repository.finish(sessionId: session.id)
        } catch {
            self.error = String(describing: error)
            return nil
        }
    }

    private func replace(_ set: LoggedSet) {
        guard let index = sets[set.prescribedExerciseId]?.firstIndex(where: { $0.id == set.id }) else { return }
        sets[set.prescribedExerciseId]?[index] = set
    }

    private func persist(_ set: LoggedSet) async {
        do {
            try await repository.save(set)
        } catch {
            self.error = String(describing: error)
        }
    }
}
