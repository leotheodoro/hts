/// Fixed title catalog (docs/decisions/0021).
public enum TitleID: String, Hashable, Sendable, Codable, CaseIterable {
    case firstSession = "first-session"
    case recruitmentComplete = "recruitment-complete"
    case perfectWeek = "perfect-week"
    case streakLit = "streak-lit"
    case limitBroken10 = "limit-broken-10"
    case hundredBars = "hundred-bars"
    case readyForBattle = "ready-for-battle"
}

/// What a completed session contributes to the titles. Mirrors `TitleSession` in packages/progression.
public struct TitleSession: Hashable, Sendable, Decodable {
    public enum CompletedArc: String, Hashable, Sendable, Decodable {
        /// Closed the athlete's first arc (Recrutamento).
        case first
        /// Closed a special arc (Véspera).
        case special
    }

    public let localDate: LocalDate
    public let weeklyGoal: Int?
    public let records: Int
    public let pullUpSets: Int
    public let completedArc: CompletedArc?

    public init(localDate: LocalDate, weeklyGoal: Int?, records: Int, pullUpSets: Int, completedArc: CompletedArc?) {
        self.localDate = localDate
        self.weeklyGoal = weeklyGoal
        self.records = records
        self.pullUpSets = pullUpSets
        self.completedArc = completedArc
    }
}

public struct UnlockedTitle: Hashable, Sendable, Decodable {
    public let id: TitleID
    public let unlockedOn: LocalDate
}

extension Progression {
    /// Must match `titles` in packages/progression; both run packages/fixtures/titles.json.
    public func titles(_ sessions: [TitleSession]) -> [UnlockedTitle] {
        var unlocked: [UnlockedTitle] = []
        func unlock(_ id: TitleID, _ date: LocalDate) {
            guard !unlocked.contains(where: { $0.id == id }) else { return }
            unlocked.append(UnlockedTitle(id: id, unlockedOn: date))
        }
        var records = 0
        var pullUps = 0
        var week: LocalDate?
        var done = 0
        var goal = 0
        var met = false
        var runBefore = 0
        for session in sessions {
            records += session.records
            pullUps += session.pullUpSets
            unlock(.firstSession, session.localDate)
            if session.completedArc == .first { unlock(.recruitmentComplete, session.localDate) }
            if records >= 10 { unlock(.limitBroken10, session.localDate) }
            // Filler sessions only give XP: they never count for the week (docs/decisions/0030).
            if let weeklyGoal = session.weeklyGoal {
                let start = session.localDate.weekStart
                if start != week {
                    if let week {
                        let run = met ? runBefore + 1 : 0
                        runBefore = start == week.adding(days: 7) ? run : 0
                    }
                    week = start
                    done = 0
                    goal = 0
                    met = false
                }
                done += 1
                goal = max(goal, weeklyGoal)
                if !met && done >= goal {
                    met = true
                    unlock(.perfectWeek, session.localDate)
                    if runBefore + 1 >= 4 { unlock(.streakLit, session.localDate) }
                }
            }
            if pullUps >= 100 { unlock(.hundredBars, session.localDate) }
            if session.completedArc == .special { unlock(.readyForBattle, session.localDate) }
        }
        return unlocked
    }
}

/// Names that count as "barra fixa" for the Cem Barras title, normalized (docs/decisions/0021).
public enum PullUp {
    public static let names: Set<String> = [
        "barra fixa", "barra", "pull-up", "pull up", "pullup", "chin-up", "chin up",
    ]
}
