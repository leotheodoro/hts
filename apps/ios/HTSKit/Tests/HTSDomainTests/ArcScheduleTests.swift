import Foundation
import Testing

@testable import HTSDomain

@Suite struct ArcScheduleTests {
    let start = LocalDate("2026-11-02")!

    @Test func totalIsTemplatesTimesWeeks() {
        let schedule = ArcSchedule(letters: ["A", "B", "C"], weeks: 2, startDate: start)
        #expect(schedule.totalSessions == 6)
        #expect(schedule.weeklyGoal == 3)
        #expect(schedule.weekGrid == [["A", "B", "C"], ["A", "B", "C"]])
    }

    @Test func endDateIsStartPlusWeeksTimesSevenMinusOne() {
        #expect(
            ArcSchedule(letters: ["A"], weeks: 2, startDate: start).endDate(today: start) == LocalDate("2026-11-15"))
    }

    @Test func endDateCrossesMonthAndYear() {
        let december = ArcSchedule(letters: ["A", "B"], weeks: 8, startDate: LocalDate("2026-12-14")!)
        #expect(december.endDate(today: start) == LocalDate("2027-02-07"))
        let leap = ArcSchedule(letters: ["A"], weeks: 1, startDate: LocalDate("2028-02-25")!)
        #expect(leap.endDate(today: start) == LocalDate("2028-03-02"))
    }

    /// Paused days move the end of the arc (docs/decisions/0038).
    @Test func pausedDaysMoveTheEnd() {
        let pause = PauseInterval(startDate: LocalDate("2026-11-16")!, endDate: LocalDate("2026-11-23")!)
        let schedule = ArcSchedule(letters: ["A"], weeks: 2, startDate: LocalDate("2026-11-16")!, pauses: [pause])
        #expect(schedule.endDate(today: LocalDate("2026-11-30")!) == LocalDate("2026-12-06"))
        #expect(!schedule.isPaused)
    }

    @Test func openPauseMovesTheEndUntilToday() {
        let pause = PauseInterval(startDate: LocalDate("2026-11-16")!, endDate: nil)
        let schedule = ArcSchedule(letters: ["A"], weeks: 2, startDate: LocalDate("2026-11-16")!, pauses: [pause])
        #expect(schedule.isPaused)
        #expect(schedule.endDate(today: LocalDate("2026-11-18")!) == LocalDate("2026-12-02"))
        #expect(!schedule.isOverdue(today: LocalDate("2026-12-10")!, completedSessions: 0))
    }

    @Test func daysPausedBeforeTheStartDoNotMoveTheEnd() {
        let pause = PauseInterval(startDate: LocalDate("2026-11-13")!, endDate: LocalDate("2026-11-17")!)
        let schedule = ArcSchedule(letters: ["A"], weeks: 2, startDate: LocalDate("2026-11-16")!, pauses: [pause])
        #expect(schedule.endDate(today: LocalDate("2026-11-30")!) == LocalDate("2026-11-30"))
    }

    @Test func overlappingPausesCountOnce() {
        let pauses = [
            PauseInterval(startDate: LocalDate("2026-11-16")!, endDate: LocalDate("2026-11-23")!),
            PauseInterval(startDate: LocalDate("2026-11-18")!, endDate: LocalDate("2026-11-20")!),
        ]
        let schedule = ArcSchedule(letters: ["A"], weeks: 2, startDate: LocalDate("2026-11-16")!, pauses: pauses)
        #expect(schedule.endDate(today: LocalDate("2026-11-30")!) == LocalDate("2026-12-06"))
    }

    /// A queued arc starts on the Monday after the previous one ends (#220).
    @Test func nextMondayIsStrictlyAfter() {
        #expect(LocalDate("2026-11-13")!.nextMonday == LocalDate("2026-11-16"))  // Friday
        #expect(LocalDate("2026-11-15")!.nextMonday == LocalDate("2026-11-16"))  // Sunday
        #expect(LocalDate("2026-11-16")!.nextMonday == LocalDate("2026-11-23"))  // Monday
        #expect(LocalDate("2026-12-29")!.nextMonday == LocalDate("2027-01-04"))
    }

    @Test func fillerArcsHaveNoDuration() {
        let filler = ArcSchedule(letters: ["A", "B"], weeks: nil, startDate: nil)
        #expect(filler.totalSessions == nil)
        #expect(filler.endDate(today: start) == nil)
        #expect(!filler.isOverdue(today: start, completedSessions: 0))
        #expect(!filler.isComplete(completedSessions: 100))
    }

    @Test func overdueOnlyAfterTheEndWithSessionsMissing() {
        let schedule = ArcSchedule(letters: ["A", "B", "C"], weeks: 2, startDate: start)
        #expect(!schedule.isOverdue(today: LocalDate("2026-11-15")!, completedSessions: 2))
        #expect(schedule.isOverdue(today: LocalDate("2026-11-16")!, completedSessions: 5))
        #expect(!schedule.isOverdue(today: LocalDate("2026-11-16")!, completedSessions: 6))
        #expect(schedule.isComplete(completedSessions: 6))
    }

    @Test func lettersFollowTheOrder() {
        #expect((0..<4).map(TemplateLetter.letter(at:)) == ["A", "B", "C", "D"])
        #expect(TemplateLetter.letter(at: 26) == "AA")
    }

    @Test func localDateArithmetic() {
        #expect(start.adding(days: -2) == LocalDate("2026-10-31"))
        #expect(start.days(to: LocalDate("2026-11-15")!) == 13)
    }
}

@Suite struct WeekTests {
    @Test func weeksRunMondayToSunday() {
        #expect(LocalDate("2026-11-04")!.weekStart == LocalDate("2026-11-02"))  // Wednesday
        #expect(LocalDate("2026-11-02")!.weekStart == LocalDate("2026-11-02"))  // Monday
        #expect(LocalDate("2026-11-08")!.weekStart == LocalDate("2026-11-02"))  // Sunday
        #expect(LocalDate("2027-01-01")!.weekStart == LocalDate("2026-12-28"))  // across the year
        #expect(LocalDate("2026-11-04")!.weekEnd == LocalDate("2026-11-08"))
    }
}

@Suite struct BattleTests {
    @Test func countsDaysAndFlagsTheEve() {
        let battle = Battle(
            id: UUID(), athleteId: UUID(), seasonId: UUID(), name: "Copa", date: LocalDate("2026-12-12")!,
            createdAt: .now)
        #expect(battle.daysUntil(LocalDate("2026-12-01")!) == 11)
        #expect(!battle.isEve(LocalDate("2026-12-05")!))
        #expect(battle.isEve(LocalDate("2026-12-06")!))
        #expect(battle.isEve(LocalDate("2026-12-12")!))
        #expect(!battle.isEve(LocalDate("2026-12-13")!))
    }
}
