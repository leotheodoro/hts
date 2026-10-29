/// A completed session as the streak sees it. Mirrors `StreakSession` in packages/progression.
public struct StreakSession: Hashable, Sendable, Decodable {
    public let localDate: LocalDate
    /// Sessions per week of the session's arc; nil for filler (Manutenção) arcs.
    public let weeklyGoal: Int?

    public init(localDate: LocalDate, weeklyGoal: Int?) {
        self.localDate = localDate
        self.weeklyGoal = weeklyGoal
    }
}

public struct Streak: Hashable, Sendable {
    public struct Week: Hashable, Sendable, Decodable {
        public let done: Int
        public let goal: Int
    }

    /// Consecutive weeks with the goal met, up to now. The week in progress only adds once met.
    public let current: Int
    public let best: Int
    public let thisWeek: Week
}

extension Progression {
    /// Weekly streak (docs/decisions/0020). Must match `streak` in packages/progression; both run
    /// packages/fixtures/streak.json.
    public func streak(_ sessions: [StreakSession], today: LocalDate) -> Streak {
        var weeks: [LocalDate: (done: Int, goal: Int?)] = [:]
        // Filler sessions only give XP: they never count for the week (docs/decisions/0030).
        for session in sessions {
            guard let goal = session.weeklyGoal else { continue }
            let week = session.localDate.weekStart
            var entry = weeks[week] ?? (0, nil)
            entry.done += 1
            entry.goal = max(entry.goal ?? 0, goal)
            weeks[week] = entry
        }
        let current = today.weekStart
        var week = min(weeks.keys.min() ?? current, current)
        var lastGoal = 0
        var run = 0
        var best = 0
        var beforeCurrent = 0
        var thisWeek = Streak.Week(done: 0, goal: 0)
        while week <= current {
            let entry = weeks[week]
            if let goal = entry?.goal { lastGoal = goal }
            let goal = entry?.goal ?? lastGoal
            let done = entry?.done ?? 0
            let met = done > 0 && done >= goal
            if week == current {
                beforeCurrent = run
                thisWeek = Streak.Week(done: done, goal: goal)
                if met { run += 1 }
            } else {
                run = met ? run + 1 : 0
            }
            best = max(best, run)
            week = week.adding(days: 7)
        }
        let met = thisWeek.done > 0 && thisWeek.done >= thisWeek.goal
        return Streak(current: met ? beforeCurrent + 1 : beforeCurrent, best: best, thisWeek: thisWeek)
    }
}
