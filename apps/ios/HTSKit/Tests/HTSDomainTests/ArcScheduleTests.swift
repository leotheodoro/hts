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
        #expect(ArcSchedule(letters: ["A"], weeks: 2, startDate: start).endDate == LocalDate("2026-11-15"))
    }

    @Test func endDateCrossesMonthAndYear() {
        let december = ArcSchedule(letters: ["A", "B"], weeks: 8, startDate: LocalDate("2026-12-14")!)
        #expect(december.endDate == LocalDate("2027-02-07"))
        let leap = ArcSchedule(letters: ["A"], weeks: 1, startDate: LocalDate("2028-02-25")!)
        #expect(leap.endDate == LocalDate("2028-03-02"))
    }

    @Test func fillerArcsHaveNoDuration() {
        let filler = ArcSchedule(letters: ["A", "B"], weeks: nil, startDate: nil)
        #expect(filler.totalSessions == nil)
        #expect(filler.endDate == nil)
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
