import Foundation
import Testing

@testable import HTSDomain

/// Evolução (#202): estimated 1RM (Epley) and what the exercise page compares.
@Suite struct ExerciseEvolutionTests {
    let day: TimeInterval = 86_400
    let now = Date(timeIntervalSince1970: 1_794_142_800)

    func workout(daysAgo: Double, sets: [(Decimal, Int)]) -> ExerciseEvolution.Workout {
        ExerciseEvolution.Workout(
            date: now.addingTimeInterval(-daysAgo * day), sets: sets.map { .init(weightKg: $0.0, reps: $0.1) })!
    }

    @Test func epleyAddsAThirtiethPerRep() {
        #expect(OneRepMax.epley(weightKg: 110, reps: 3) == 121)
        #expect(OneRepMax.epley(weightKg: 120, reps: 4) == 136)
        #expect(OneRepMax.epley(weightKg: 100, reps: 1) == 100)
    }

    @Test func aWorkoutKeepsItsBestSetByEstimatedMax() throws {
        // 130 × 1 = 130 against 120 × 4 = 136: the 4 reps set is the better one; 130 is still the heaviest.
        let one = workout(daysAgo: 0, sets: [(130, 1), (120, 4), (100, 8)])
        #expect(one.best == .init(weightKg: 120, reps: 4))
        #expect(one.estimatedMax == 136)
        #expect(one.heaviestKg == 130)
        #expect(ExerciseEvolution.Workout(date: now, sets: []) == nil)
    }

    @Test func comparesTheLatestWorkoutWithTheBestOneAMonthAgo() {
        let evolution = ExerciseEvolution(
            exerciseId: UUID(), name: "Levantamento Terra",
            workouts: [
                workout(daysAgo: 100, sets: [(80, 5)]),
                workout(daysAgo: 31, sets: [(110, 3)]),
                workout(daysAgo: 45, sets: [(100, 3)]),
                workout(daysAgo: 10, sets: [(125, 1)]),
                workout(daysAgo: 0, sets: [(120, 4)]),
            ])
        #expect(evolution.workouts.map(\.estimatedMax) == [OneRepMax.epley(weightKg: 80, reps: 5), 110, 121, 125, 136])
        #expect(evolution.latest?.best == .init(weightKg: 120, reps: 4))
        #expect(evolution.monthAgo(now: now)?.best == .init(weightKg: 110, reps: 3))
        #expect(evolution.change(now: now) == 15)
        #expect(evolution.first?.best == .init(weightKg: 80, reps: 5))
        #expect(evolution.heaviest?.heaviestKg == 125)
        #expect(evolution.bestEstimatedMax?.estimatedMax == 136)
    }

    @Test func aNewExerciseHasNoMonthToCompare() {
        let evolution = ExerciseEvolution(
            exerciseId: UUID(), name: "Supino", workouts: [workout(daysAgo: 3, sets: [(60, 8)])])
        #expect(evolution.monthAgo(now: now) == nil)
        #expect(evolution.change(now: now) == nil)
    }

    @Test func theSentenceSaysWhatChanged() {
        let then = ExerciseEvolution.Lift(weightKg: 110, reps: 3)
        #expect(ExerciseEvolution.Lift(weightKg: 120, reps: 4).gain(over: then) == .init(kg: 10, reps: 1))
        #expect(ExerciseEvolution.Lift(weightKg: 110, reps: 5).gain(over: then) == .init(kg: 0, reps: 2))
    }
}
