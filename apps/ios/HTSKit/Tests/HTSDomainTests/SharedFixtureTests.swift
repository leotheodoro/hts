import Foundation
import Testing

@testable import HTSDomain

/// Runs the same cases as `packages/progression/test/fixtures.test.ts`.
struct Fixture<Input: Decodable & Sendable, Expected: Decodable & Sendable>: Decodable, Sendable {
    struct Case: Decodable, Sendable, CustomTestStringConvertible {
        let name: String
        let input: Input
        let expected: Expected
        var testDescription: String { name }
    }
    let function: String
    let cases: [Case]

    static func load(_ file: String) -> [Case] {
        guard let url = Bundle.module.url(forResource: file, withExtension: "json", subdirectory: "Fixtures") else {
            fatalError("Fixture \(file).json not found; run pnpm sync:shared")
        }
        do {
            return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url)).cases
        } catch {
            fatalError("Invalid fixture \(file).json: \(error)")
        }
    }
}

struct XPInput: Decodable, Sendable { let xp: Int }
struct LevelOutput: Decodable, Sendable { let level: Int }
struct LevelInput: Decodable, Sendable { let level: Int }
struct RankOutput: Decodable, Sendable { let id: String, name: String }

@Suite struct SharedFixtureTests {
    let progression = Progression()

    @Test(arguments: Fixture<XPInput, LevelOutput>.load("level-for-xp"))
    func levelForXp(_ c: Fixture<XPInput, LevelOutput>.Case) {
        #expect(progression.level(forXP: c.input.xp) == c.expected.level)
    }

    @Test(arguments: Fixture<LevelInput, RankOutput>.load("rank-for-level"))
    func rankForLevel(_ c: Fixture<LevelInput, RankOutput>.Case) {
        let rank = progression.rank(forLevel: c.input.level)
        #expect(rank.id.rawValue == c.expected.id)
        #expect(rank.name == c.expected.name)
    }

    @Test(arguments: Fixture<SessionXPInput, SessionXP>.load("xp-for-session"))
    func xpForSession(_ c: Fixture<SessionXPInput, SessionXP>.Case) {
        #expect(progression.xp(for: c.input) == c.expected)
    }

    /// The seed of the API reads the coach's notation with the same rules (apps/api/src/seed/notation.ts).
    @Test(arguments: Fixture<NotationInput, NotationOutput?>.load("target-notation"))
    func targetNotation(_ c: Fixture<NotationInput, NotationOutput?>.Case) {
        let sets = TargetNotation.parseSets(c.input.sets)
        let parsed = sets.flatMap { TargetNotation.parse(c.input.target, setsMax: $0.max) }
        let actual = sets.flatMap { sets in
            parsed.map {
                NotationOutput(setsMin: sets.min, setsMax: sets.max, targets: $0.targets, perSide: $0.perSide)
            }
        }
        #expect(actual == c.expected)
    }

    @Test func everyFixtureFileIsCovered() throws {
        let urls = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "Fixtures") ?? []
        let names = Set(urls.map { $0.deletingPathExtension().lastPathComponent })
        #expect(
            names == [
                "activity-link", "activity-xp", "attribute-levels", "level-for-xp", "normalize-exercise-name",
                "progress-history", "rank-for-level",
                "streak", "target-notation",
                "titles", "xp-for-session",
            ])
    }
}

struct NotationInput: Decodable, Sendable { let sets: String, target: String }
struct NotationOutput: Decodable, Sendable, Equatable {
    let setsMin: Int
    let setsMax: Int
    let targets: [SetTarget]
    let perSide: Bool
}

struct HistoryInput: Decodable, Sendable {
    let sessions: [HistorySession]
    let activities: [HistoryActivity]?
}

struct HistoryOutput: Decodable, Sendable {
    struct Session: Decodable, Sendable {
        let completedSets: Int
        let volumeKg: String
        let records: [String]
        let xp: Int
    }
    let sessions: [Session]
    let totalXp: Int
    let level: Int
    let rank: String
}

@Suite struct ProgressHistoryFixtureTests {
    @Test(arguments: Fixture<HistoryInput, HistoryOutput>.load("progress-history"))
    func progressHistory(_ c: Fixture<HistoryInput, HistoryOutput>.Case) {
        let history = Progression().history(c.input.sessions, activities: c.input.activities ?? [])
        #expect(history.totalXp == c.expected.totalXp)
        #expect(history.level == c.expected.level)
        #expect(history.rank.id.rawValue == c.expected.rank)
        #expect(history.sessions.map(\.xp) == c.expected.sessions.map(\.xp))
        #expect(history.sessions.map(\.records) == c.expected.sessions.map(\.records))
        #expect(history.sessions.map(\.completedSets) == c.expected.sessions.map(\.completedSets))
        #expect(
            history.sessions.map { NSDecimalNumber(decimal: $0.volumeKg).stringValue }
                == c.expected.sessions.map(\.volumeKg))
    }
}

struct StreakInput: Decodable, Sendable {
    let today: LocalDate
    let sessions: [StreakSession]
}

struct StreakOutput: Decodable, Sendable {
    let current: Int
    let best: Int
    let thisWeek: Streak.Week
}

@Suite struct StreakFixtureTests {
    @Test(arguments: Fixture<StreakInput, StreakOutput>.load("streak"))
    func streak(_ c: Fixture<StreakInput, StreakOutput>.Case) {
        let streak = Progression().streak(c.input.sessions, today: c.input.today)
        #expect(streak.current == c.expected.current)
        #expect(streak.best == c.expected.best)
        #expect(streak.thisWeek == c.expected.thisWeek)
    }
}

struct TitlesInput: Decodable, Sendable { let sessions: [TitleSession] }
struct TitlesOutput: Decodable, Sendable { let titles: [UnlockedTitle] }

@Suite struct TitlesFixtureTests {
    @Test(arguments: Fixture<TitlesInput, TitlesOutput>.load("titles"))
    func titles(_ c: Fixture<TitlesInput, TitlesOutput>.Case) {
        #expect(Progression().titles(c.input.sessions) == c.expected.titles)
    }
}

struct AttributeInput: Decodable, Sendable {
    let sets: [AttributeSet]
    let activities: [ActivityAttributeXP]?
}

@Suite struct AttributeLevelsFixtureTests {
    @Test(arguments: Fixture<AttributeInput, [String: AttributeLevel]>.load("attribute-levels"))
    func attributeLevels(_ c: Fixture<AttributeInput, [String: AttributeLevel]>.Case) {
        let levels = Progression().attributeLevels(c.input.sets, activities: c.input.activities ?? [])
        #expect(Dictionary(uniqueKeysWithValues: levels.map { ($0.key.rawValue, $0.value) }) == c.expected)
    }
}

struct ActivityXPInput: Decodable, Sendable {
    let activityType: String
    let durationSeconds: Int
}

struct ActivityLinkInput: Decodable, Sendable {
    struct Activity: Decodable, Sendable {
        let startedAt: String
        let durationSeconds: Int
    }
    struct Session: Decodable, Sendable {
        let startedAt: String
        let finishedAt: String
    }
    let activity: Activity
    let sessions: [Session]
}

struct ActivityLinkOutput: Decodable, Sendable { let linked: Bool }

@Suite struct ActivityFixtureTests {
    @Test(arguments: Fixture<ActivityXPInput, ActivityXP>.load("activity-xp"))
    func activityXP(_ c: Fixture<ActivityXPInput, ActivityXP>.Case) {
        #expect(
            Progression().activityXP(activityType: c.input.activityType, durationSeconds: c.input.durationSeconds)
                == c.expected)
    }

    @Test(arguments: Fixture<ActivityLinkInput, ActivityLinkOutput>.load("activity-link"))
    func activityLink(_ c: Fixture<ActivityLinkInput, ActivityLinkOutput>.Case) {
        let date = { (text: String) in
            try! Date(text, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true))
        }
        let linked = Progression().isActivityLinked(
            startedAt: date(c.input.activity.startedAt), durationSeconds: c.input.activity.durationSeconds,
            sessions: c.input.sessions.map { (startedAt: date($0.startedAt), finishedAt: date($0.finishedAt)) })
        #expect(linked == c.expected.linked)
    }
}
