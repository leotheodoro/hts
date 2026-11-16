/// A pause of an arc (docs/decisions/0038). It covers `startDate` up to the day before `endDate`; an open pause
/// (`endDate` nil) covers up to today. Pausing and resuming on the same day covers nothing. Mirrors
/// `PauseInterval` in packages/progression.
public struct PauseInterval: Hashable, Sendable, Decodable {
    public let startDate: LocalDate
    public let endDate: LocalDate?

    public init(startDate: LocalDate, endDate: LocalDate?) {
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Days covered by any of `pauses` between `from` and `today`, inclusive. Overlapping pauses count once.
    public static func coveredDays(_ pauses: [PauseInterval], from: LocalDate, through today: LocalDate)
        -> Set<LocalDate>
    {
        var days: Set<LocalDate> = []
        for pause in pauses {
            var day = max(pause.startDate, from)
            let end = pause.endDate ?? today.adding(days: 1)
            while day < end && day <= today {
                days.insert(day)
                day = day.adding(days: 1)
            }
        }
        return days
    }

    /// Mondays of the weeks with at least one day covered by a pause, up to `today`.
    public static func pausedWeeks(_ pauses: [PauseInterval], today: LocalDate) -> Set<LocalDate> {
        var weeks: Set<LocalDate> = []
        for pause in pauses {
            let end = pause.endDate ?? today.adding(days: 1)
            guard pause.startDate < end else { continue }
            var week = pause.startDate.weekStart
            while week < end {
                weeks.insert(week)
                week = week.adding(days: 7)
            }
        }
        return weeks
    }
}
