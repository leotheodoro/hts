/// The arc rule (docs/product/handoff-produto.md, Arcos e treinos): total sessions = templates × weeks, done
/// within those weeks, rotating A, B, C. Filler arcs have no duration.
public struct ArcSchedule: Hashable, Sendable {
    public let letters: [String]
    public let weeks: Int?
    public let startDate: LocalDate?

    public init(letters: [String], weeks: Int?, startDate: LocalDate?) {
        self.letters = letters
        self.weeks = weeks
        self.startDate = startDate
    }

    public init(_ plan: ArcPlan) {
        self.init(letters: plan.templates.map(\.template.letter), weeks: plan.arc.weeks, startDate: plan.arc.startDate)
    }

    /// Sessions per week, which is also the weekly goal for the streak.
    public var weeklyGoal: Int { letters.count }

    public var totalSessions: Int? { weeks.map { $0 * letters.count } }

    /// Last day of the arc: start + weeks × 7 − 1.
    public var endDate: LocalDate? {
        guard let startDate, let weeks, weeks > 0 else { return nil }
        return startDate.adding(days: weeks * 7 - 1)
    }

    /// One row per week with the letters in rotation (A, B, C, A, B, C…).
    public var weekGrid: [[String]] {
        guard let weeks else { return [] }
        return Array(repeating: letters, count: max(weeks, 0))
    }

    /// Past the end date with sessions still missing. The arc stays current; the app only flags it
    /// (docs/decisions/0018).
    public func isOverdue(today: LocalDate, completedSessions: Int) -> Bool {
        guard let endDate, let totalSessions else { return false }
        return today > endDate && completedSessions < totalSessions
    }

    public func isComplete(completedSessions: Int) -> Bool {
        guard let totalSessions else { return false }
        return completedSessions >= totalSessions
    }
}

/// Template letters follow the order: A, B, C… Z, then AA, AB…
public enum TemplateLetter {
    public static func letter(at index: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return index < 26 ? String(alphabet[index]) : letter(at: index / 26 - 1) + String(alphabet[index % 26])
    }
}
