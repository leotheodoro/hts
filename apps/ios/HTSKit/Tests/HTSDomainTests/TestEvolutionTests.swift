import Foundation
import Testing

@testable import HTSDomain

/// Treino teste (#216): the last run side by side with the one before, the best set of each exercise.
@Suite struct TestEvolutionTests {
    let lSit = UUID()
    let plank = UUID()
    let squat = UUID()
    let bike = UUID()

    func exercise(_ id: UUID, _ name: String, _ unit: ExerciseUnit) -> PlanSnapshot.Exercise {
        PlanSnapshot.Exercise(
            prescribedExerciseId: UUID(), exerciseId: id, name: name, unit: unit, perSide: false, setsMin: 1,
            setsMax: 3, targets: [.max], restSeconds: nil)
    }

    func set(
        _ exerciseId: UUID, weightKg: Decimal? = nil, reps: Int? = nil, seconds: Int? = nil, meters: Decimal? = nil,
        completed: Bool = true
    ) -> LoggedSet {
        LoggedSet(
            id: UUID(), athleteId: UUID(), sessionId: UUID(), prescribedExerciseId: UUID(), exerciseId: exerciseId,
            setNumber: 1, weightKg: weightKg, reps: reps, seconds: seconds, meters: meters, completed: completed,
            createdAt: .now)
    }

    var exercises: [PlanSnapshot.Exercise] {
        [exercise(lSit, "L-Sit Máximo", .seconds), exercise(plank, "Prancha Máxima", .seconds)]
    }

    @Test func comparesTheBestSetOfEachExercise() throws {
        let previous = TestRun(
            date: LocalDate("2026-09-14")!, exercises: exercises,
            sets: [set(lSit, seconds: 15), set(lSit, seconds: 18), set(plank, seconds: 130)])
        let latest = TestRun(
            date: LocalDate("2026-10-12")!, exercises: exercises,
            sets: [set(lSit, seconds: 26), set(plank, seconds: 125), set(plank, seconds: 200, completed: false)])
        let evolution = try #require(TestEvolution(runs: [latest, previous]))
        #expect(evolution.latestDate == LocalDate("2026-10-12"))
        #expect(evolution.previousDate == LocalDate("2026-09-14"))
        #expect(
            evolution.rows == [
                .init(name: "L-Sit Máximo", previous: "18 s", latest: "26 s", delta: "+8 s", trend: .better),
                .init(name: "Prancha Máxima", previous: "2:10", latest: "2:05", delta: "−5 s", trend: .worse),
            ])
    }

    @Test func oneRunHasOneColumn() throws {
        let only = TestRun(date: LocalDate("2026-10-12")!, exercises: exercises, sets: [set(lSit, seconds: 26)])
        let evolution = try #require(TestEvolution(runs: [only]))
        #expect(evolution.previousDate == nil)
        #expect(
            evolution.rows == [
                .init(name: "L-Sit Máximo", previous: nil, latest: "26 s", delta: nil, trend: nil),
                .init(name: "Prancha Máxima", previous: nil, latest: nil, delta: nil, trend: nil),
            ])
    }

    @Test func neverDoneHasNoTable() {
        #expect(TestEvolution(runs: []) == nil)
    }

    /// With a load the load is compared; calories are kept in reps; equal is neither better nor worse.
    @Test func loadsCaloriesAndTies() throws {
        let exercises = [exercise(squat, "Back Squat", .reps), exercise(bike, "Bike Max Cal", .calories)]
        let previous = TestRun(
            date: LocalDate("2026-09-14")!, exercises: exercises,
            sets: [set(squat, weightKg: 100, reps: 3), set(bike, reps: 18)])
        let latest = TestRun(
            date: LocalDate("2026-10-12")!, exercises: exercises,
            sets: [set(squat, weightKg: 102.5, reps: 1), set(squat, weightKg: 90, reps: 5), set(bike, reps: 18)])
        let evolution = try #require(TestEvolution(runs: [latest, previous]))
        #expect(
            evolution.rows == [
                .init(name: "Back Squat", previous: "100 kg", latest: "102,5 kg", delta: "+2,5 kg", trend: .better),
                .init(name: "Bike Max Cal", previous: "18 cal", latest: "18 cal", delta: "=", trend: .same),
            ])
    }

    @Test func metersAndMinutes() throws {
        let jump = UUID()
        let run = UUID()
        let exercises = [exercise(jump, "Salto em Distância", .meters), exercise(run, "Corrida", .minutes)]
        let previous = TestRun(
            date: LocalDate("2026-09-14")!, exercises: exercises,
            sets: [set(jump, meters: 2.3), set(run, seconds: 720)])
        let latest = TestRun(
            date: LocalDate("2026-10-12")!, exercises: exercises,
            sets: [set(jump, meters: 2.45), set(run, seconds: 690)])
        let evolution = try #require(TestEvolution(runs: [latest, previous]))
        #expect(
            evolution.rows == [
                .init(
                    name: "Salto em Distância", previous: "2,3 m", latest: "2,45 m", delta: "+0,15 m", trend: .better),
                .init(name: "Corrida", previous: "12 min", latest: "11,5 min", delta: "−0,5 min", trend: .worse),
            ])
    }

    /// "5 km no menor tempo" (#218): the fastest run of the session counts, and a lower time is better.
    @Test func lowerIsBetterOnTimedTests() throws {
        let run = UUID()
        var timed = exercise(run, "Corrida 5 km", .seconds)
        timed.lowerIsBetter = true
        let previous = TestRun(
            date: LocalDate("2026-09-14")!, exercises: [timed],
            sets: [set(run, seconds: 1_560), set(run, seconds: 1_620)])
        let latest = TestRun(date: LocalDate("2026-10-12")!, exercises: [timed], sets: [set(run, seconds: 1_530)])
        let evolution = try #require(TestEvolution(runs: [latest, previous]))
        #expect(
            evolution.rows == [
                .init(name: "Corrida 5 km", previous: "26:00", latest: "25:30", delta: "−30 s", trend: .better)
            ])
    }
}
