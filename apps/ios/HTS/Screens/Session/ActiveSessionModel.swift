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

    private let repository: SessionRepository

    init(database: AppDatabase, session: Session) {
        self.session = session
        repository = SessionRepository(database)
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
