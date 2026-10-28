import Foundation
import Testing

@testable import HTSDomain

@Suite struct ActiveSessionRulesTests {
    let now = Date(timeIntervalSince1970: 1_793_000_000)

    func set(kg: Decimal? = nil, reps: Int? = nil) -> LoggedSet {
        LoggedSet(
            id: UUID(), athleteId: UUID(), sessionId: UUID(), prescribedExerciseId: UUID(), exerciseId: UUID(),
            setNumber: 1, weightKg: kg, reps: reps, createdAt: now)
    }

    @Test func nextFollowsTheRotation() {
        let schedule = ArcSchedule(letters: ["A", "B", "C"], weeks: 2, startDate: nil)
        #expect(schedule.next(after: nil) == "A")
        #expect(schedule.next(after: "A") == "B")
        #expect(schedule.next(after: "C") == "A")
        #expect(schedule.next(after: "Z") == "A")
        #expect(ArcSchedule(letters: [], weeks: nil, startDate: nil).next(after: nil) == nil)
    }

    @Test func checkingFillsEmptyFieldsWithTargetAndPreviousLoad() {
        let previous = set(kg: 60, reps: 5)
        let checked = SetRules.check(set(), unit: .reps, target: .fixed(6), previous: previous, at: now)
        #expect(checked.completed)
        #expect(checked.weightKg == 60)
        #expect(checked.reps == 6)
        #expect(checked.completedAt == now)
    }

    @Test func checkingKeepsWhatWasTyped() {
        let typed = set(kg: Decimal(string: "62.5"), reps: 4)
        let checked = SetRules.check(typed, unit: .reps, target: .fixed(6), previous: set(kg: 60, reps: 6), at: now)
        #expect(checked.weightKg == Decimal(string: "62.5"))
        #expect(checked.reps == 4)
    }

    @Test func maxTargetFallsBackToPreviousAmount() {
        let checked = SetRules.check(set(), unit: .reps, target: .max, previous: set(reps: 12), at: now)
        #expect(checked.reps == 12)
        let first = SetRules.check(set(), unit: .reps, target: .max, previous: nil, at: now)
        #expect(first.reps == nil)
        #expect(first.completed)
    }

    @Test func timeTargetsGoToSeconds() {
        var seconds = set()
        seconds = SetRules.check(seconds, unit: .seconds, target: .range(min: 30, max: 45), previous: nil, at: now)
        #expect(seconds.seconds == 30)
        let minutes = SetRules.check(set(), unit: .minutes, target: .fixed(1.5), previous: nil, at: now)
        #expect(minutes.seconds == 90)
    }

    @Test func summaryForThePreviousColumn() {
        #expect(set(kg: 60, reps: 6).summary(unit: .reps) == "60 × 6")
        #expect(set(kg: Decimal(string: "62.5"), reps: 3).summary(unit: .reps) == "62,5 × 3")
        #expect(set(reps: 12).summary(unit: .reps) == "12")
        #expect(set().summary(unit: .reps) == nil)
    }
}
